# AUTHOR:               Damir Akchurin
# DATE CREATED:         08/07/2024
# DATE LAST MODIFIED:   08/08/2024

# Preamble:
import PyCall                       # V1.96.4
import Optimization                 # V3.27.0
import OptimizationMOI              # V0.4.2
import Ipopt                        # V1.6.5
import FiniteDiff                   # V2.23.1
import XLSX                         # V0.10.1
import StructuralDesignOptimization # Under development
using CairoMakie                    # V0.12.5
CairoMakie.activate!(type = :png, px_per_unit = 5)
set_theme!(theme_latexfonts())

# Load the OpenSeesPy package:
ops = PyCall.pyimport("openseespy.opensees")

# Define an OpenSeesPy model of a planar frame subjected to gravity loads:
# Define an OpenSeesPy model of a planar frame subjected to gravity loads:
function PlanarFrame(u, p)
    # --------------------------------------------------
    # USER INPUT
    # --------------------------------------------------
    # Unpack the design variables and parameters:
    A_g_B, I_x_B, _, A_g_C, I_x_C, _ = u
    w_D, _, NumSubdivisions, NumSteps = p

    # Make sure that the data types are correct:
    NumSubdivisions = Int(NumSubdivisions)
    NumSteps        = Int(NumSteps)

    # Define the Nodes:
    # [Node ID, x-coordinate, y-coordinate]
    Nodes = [
        (1,  0 * 12, 10 * 12)
        (2, 10 * 12, 10 * 12)
        (3,  0 * 12,  0 * 12)
        (4, 10 * 12,  0 * 12)]
    
    # Define the elements:
    # [Element ID, Node (i) ID, Node (j) ID, Young's modulus, Gross cross-sectional area, Moment of inertia]
    Elements = [
        (1, 1, 2, 29000, A_g_B, I_x_B)
        (2, 3, 1, 29000, A_g_C, I_x_C)
        (3, 4, 2, 29000, A_g_C, I_x_C)]

    # Define the boundary conditions:
    BoundaryConditions = [
        (3, 1, 1, 1)
        (4, 1, 1, 1)]

    # Define the distributed loads:
    DistributedLoads = [
        (1, w_D)]

    # --------------------------------------------------
    # DO NOT MODIFY THE CODE BELOW
    # --------------------------------------------------
    # Subdivide the elements:
    NewNodes, NewElements, _, ElementMap = StructuralDesignOptimization.SubdivideElements(Nodes, Elements, NumSubdivisions)

    # Compute the element properties of the original elements:
    L, α = StructuralDesignOptimization.ComputeElementProperties(NewNodes, NewElements)

    # Remove any previous models:
    ops.wipe()

    # Define the model parameters:
    ops.model("basic", "-ndm", 2, "-ndf", 3)

    # Define the Nodes:
    for NewNode in NewNodes
        ops.node(NewNode...)
    end

    # Define the boundary conditions:
    for BoundaryCondition in BoundaryConditions
        ops.fix(BoundaryCondition...)
    end

    # Define the cross-sectional properties:
    for NewElement in NewElements
        ops.section("Elastic", NewElement[1], NewElement[4], NewElement[5], NewElement[6])
    end

    # Define the transformation:
    ops.geomTransf("PDelta", 1)

    # Define the elements:
    for NewElement in NewElements
        ops.element("elasticBeamColumn", NewElement[1], NewElement[2], NewElement[3], NewElement[1], 1)
    end

    # Define the loads:
    ops.timeSeries("Linear", 1)
    ops.pattern("Plain", 1, 1)
    for DistributedLoads in DistributedLoads
        for i in ElementMap[DistributedLoads[1], 2:end]
            ops.eleLoad("-ele", i, "-type", "-beamUniform", DistributedLoads[2])
        end
    end

    # Define the solver parameters:
    ops.system("BandSPD")
    ops.numberer("RCM")
    ops.constraints("Plain")
    ops.algorithm("Linear")

    # Solve:
    ops.integrator("LoadControl", 1 / NumSteps)
    ops.analysis("Static")
    ops.analyze(NumSteps)

    # Compute the internal element forces in global coordinates:
    GlobalElementForces = [ops.eleForce(i) for i in eachindex(NewElements)]

    # Compute the internal element forces in local coordinates:
    LocalElementForces = StructuralDesignOptimization.ConvertElementForcesG2L(NewElements, GlobalElementForces, α)

    # Convert the internal forces to a common sign convention:
    LocalElementForces[:, 1:3] = (-1) * LocalElementForces[:, 1:3]

    # Extract the internal forces:
    N = zeros(length(Elements), 1 + NumSubdivisions + 1) # Interal axial forces
    M = zeros(length(Elements), 1 + NumSubdivisions + 1) # Interal bending moments
    for Element in Elements
        N[Element[1], 1] = Element[1]
        M[Element[1], 1] = Element[1]

        for i in 1:NumSubdivisions
            N[Element[1], 1 + i] = LocalElementForces[ElementMap[Element[1], 1 + i], 1]
            M[Element[1], 1 + i] = LocalElementForces[ElementMap[Element[1], 1 + i], 3]

            if i == NumSubdivisions
                N[Element[1], 1 + i + 1] = LocalElementForces[ElementMap[Element[1], 1 + i], 4]
                M[Element[1], 1 + i + 1] = LocalElementForces[ElementMap[Element[1], 1 + i], 6]
            end
        end
    end

    # Compute the required strengths:
    M_r = Float64[]
    P_r = Float64[]
    for Element in Elements
        # Find the point of maximum bending moment:
        _, M_r_temp_loc = findmax(abs.(M[Element[1], 2:end]))

        # Find the bending moment and axial force at the point of maximum bending moment:
        M_r_temp = M[Element[1], 1 + M_r_temp_loc]
        P_r_temp = N[Element[1], 1 + M_r_temp_loc]

        push!(M_r, M_r_temp)
        push!(P_r, P_r_temp)
    end

    # Return the result:
    return P_r, M_r
end

# Define the constraints:
EnvelopingConstraintsB = float.(XLSX.readxlsx("Enveloping Constraints.xlsx")["Beams"][2:end, :])
Ξ_B = EnvelopingConstraintsB[:, 1:3]
ξ_B = EnvelopingConstraintsB[:, 4]

EnvelopingConstraintsC = float.(XLSX.readxlsx("Enveloping Constraints.xlsx")["Columns"][2:end, :])
Ξ_C = EnvelopingConstraintsC[:, 1:3]
ξ_C = EnvelopingConstraintsC[:, 4]

TotalNumEnvelopingConstraints = size(EnvelopingConstraintsC, 1) + size(EnvelopingConstraintsB, 1)
LowerBound = [fill(-Inf, TotalNumEnvelopingConstraints); 0; 0; 0]
UpperBound = [ξ_B; ξ_C; 1; 1; 1]

function Constraints(res, u, p)
    # Define the enveloping constraints:
    EC_B = Ξ_B * u[1:3]
    EC_C = Ξ_C * u[4:6]
    
    # Define the stress constraints:
    P_r, M_r = PlanarFrame(u, p)

    # Compute the design strengths for all members:
    if P_r[1] < 0
        P_c_1 = StructuralDesignOptimization.ComputeDesignCompressiveStrength(0.90, 29000, 50, 1, 120, u[1:2]...)
    else
        P_c_1 = StructuralDesignOptimization.ComputeDesignTensileStrength(0.90, 50, u[1])
    end

    if P_r[2] < 0
        P_c_2 = StructuralDesignOptimization.ComputeDesignCompressiveStrength(0.90, 29000, 50, 1, 120, u[4:5]...)
    else
        P_c_2 = StructuralDesignOptimization.ComputeDesignTensileStrength(0.90, 50, u[4])
    end

    if P_r[3] < 0
        P_c_3 = StructuralDesignOptimization.ComputeDesignCompressiveStrength(0.90, 29000, 50, 1, 120, u[4:5]...)
    else
        P_c_3 = StructuralDesignOptimization.ComputeDesignTensileStrength(0.90, 50, u[4])
    end

    M_c_1 = StructuralDesignOptimization.ComputeDesignFlexuralStrength(0.90, 50, u[3])
    M_c_2 = StructuralDesignOptimization.ComputeDesignFlexuralStrength(0.90, 50, u[6])
    M_c_3 = StructuralDesignOptimization.ComputeDesignFlexuralStrength(0.90, 50, u[6])

    # Define the stress constraints:
    SC = [
        StructuralDesignOptimization.ComputeBeamColumnInteraction(abs(P_r[1]), P_c_1, abs(M_r[1]), M_c_1, 0, 1)
        StructuralDesignOptimization.ComputeBeamColumnInteraction(abs(P_r[2]), P_c_2, abs(M_r[2]), M_c_2, 0, 1)
        StructuralDesignOptimization.ComputeBeamColumnInteraction(abs(P_r[3]), P_c_3, abs(M_r[3]), M_c_3, 0, 1)]

    # Combine the constraints:
    AllConstraints = [EC_B; EC_C; SC]

    return (res .= AllConstraints)
end

# Define the callback function:
Storage = []
function Callback(s, l)
    # Extract the state of the optimization problem:
    CurrentState = [s.iter, s.u, s.objective]

    # Store the state of the optimization problem:
    push!(Storage, deepcopy(CurrentState))

    return false
end

# Define the initial values:
u₀ = [
    20.0, 1000.0, 100.0, 
    10.0,  500.0,  50.0]
p₀ = [-10 / 12, 490 / 12 ^ 3, 10, 10]

# Solve the optimization problem:
Objective = Optimization.OptimizationFunction((u, p) -> p[2] * (120 * u[1] + 2 * 120 * u[4]), Optimization.AutoFiniteDiff(), cons = Constraints)
Problem   = Optimization.OptimizationProblem(Objective, u₀, p₀, 
    lb = [  3.840,    39.600,   11.400,   3.550,    11.300,    6.280],
    ub = [257.000, 18100.000, 2030.000, 272.000, 73000.000, 4130.000],
    lcons = LowerBound, 
    ucons = UpperBound)
Solution  = Optimization.solve(Problem, Ipopt.Optimizer(), callback = Callback; tol = 1E-3, acceptable_tol = 1E-3, max_iter = 100)

# Solution for the beams' section properties:
SolutionB = Matrix{Float64}(undef, length(Storage), 3)
for (i, State) in enumerate(Storage)
    SolutionB[i, :] = State[2][1:3]
end

# Solution for the columns' section properties:
SolutionC = Matrix{Float64}(undef, length(Storage), 3)
for (i, State) in enumerate(Storage)
    SolutionC[i, :] = State[2][4:6]
end

# Plot the solution:
begin
    F = Figure(size = 72 .* (8, 8))

    A = Axis(F[1, 1],
        xlabel = L"Iteration, $i$",
        ylabel = L"$A_{g}$ (in.$^2$)",
        limits = (0, length(Storage) - 1, 0, nothing),
        aspect = 16 / 9)

    scatterlines!(A, 0:(length(Storage) - 1), SolutionB[:, 1],
        color      = :crimson,
        linewidth  = 1,
        markersize = 6)

    scatterlines!(A, 0:(length(Storage) - 1), SolutionC[:, 1],
        color      = :steelblue,
        linewidth  = 1,
        markersize = 6)

    A = Axis(F[2, 1],
        xlabel = L"Iteration, $i$",
        ylabel = L"$I_{x}$ (in.$^4$)",
        limits = (0, length(Storage) - 1, 0, nothing),
        aspect = 16 / 9)

    scatterlines!(A, 0:(length(Storage) - 1), SolutionB[:, 2],
        color      = :crimson,
        linewidth  = 1,
        markersize = 6)

    scatterlines!(A, 0:(length(Storage) - 1), SolutionC[:, 2],
        color      = :steelblue,
        linewidth  = 1,
        markersize = 6)

    A = Axis(F[3, 1],
        xlabel = L"Iteration, $i$",
        ylabel = L"$Z_{x}$ (in.$^3$)",
        limits = (0, length(Storage) - 1, 0, nothing),
        aspect = 16 / 9)

    scatterlines!(A, 0:(length(Storage) - 1), SolutionB[:, 3], label = "Beam",
        color      = :crimson,
        linewidth  = 1,
        markersize = 6)

    scatterlines!(A, 0:(length(Storage) - 1), SolutionC[:, 3], label = "Columns",
        color      = :steelblue,
        linewidth  = 1,
        markersize = 6)

    Legend(F[4, 1], A, nbanks = 2, tellwidth = false, tellheight = true, framevisible = false)

    A = Axis(F[1:3, 2],
        xlabel = L"Iteration, $i$",
        ylabel = L"Weight, $W$ (lb)",
        limits = (0, length(Storage) - 1, 0, nothing),
        aspect = 16 / 9)

    SolutionObjectiveFunction = Vector{Float64}(undef, length(Storage))
    for (i, State) in enumerate(Storage)
        SolutionObjectiveFunction[i] = State[3]
    end

    band!(A, 0:(length(Storage) - 1), zeros(length(Storage)), SolutionObjectiveFunction,
        color = (:grey, 0.5))

    lines!(A, 0:(length(Storage) - 1), SolutionObjectiveFunction,
        color     = :black,
        linewidth = 1)

    text!(A, (length(Storage) - 1, SolutionObjectiveFunction[end]),
        text = L"$%$(floor(Int, SolutionObjectiveFunction[end]))$ lb",
        align = (:right, :bottom))

    display(F)
end

# Save the plot:
save("figures/OptimalSolution-2.png", F)