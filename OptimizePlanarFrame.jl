# AUTHOR:               Damir Akchurin
# DATE CREATED:         08/07/2024
# DATE LAST MODIFIED:   08/07/2024

# Preamble:
import PyCall          # V1.96.4
import Optimization    # V3.27.0
import OptimizationMOI # V0.4.2
import Ipopt           # V1.6.5
import FiniteDiff      # V2.23.1
import XLSX            # V0.10.1
import DataFrames      # V1.6.1
import LinearAlgebra   # Standard library
using CairoMakie       # V0.12.5
CairoMakie.activate!(type = :png, px_per_unit = 5)
set_theme!(theme_latexfonts())

# Load the OpenSeesPy package:
ops = PyCall.pyimport("openseespy.opensees")

# Define an OpenSeesPy model of a planar frame subjected to gravity loads:
function PlanarFrame(u, p; NumIncrements = 10)
    # Unpack the design variables and parameters:
    A_g_C, I_x_C, Z_x_C, A_g_B, I_x_B, Z_x_B = u
    E, w_D, ρ = p

    # Remove any previous models:
    ops.wipe()

    # Define the model parameters:
    ops.model("basic", "-ndm", 2, "-ndf", 3)

    # Define the nodes:
    ops.node( 1,  0 * 12, 10 * 12) # Beam
    ops.node( 2,  1 * 12, 10 * 12)
    ops.node( 3,  2 * 12, 10 * 12)
    ops.node( 4,  3 * 12, 10 * 12)
    ops.node( 5,  4 * 12, 10 * 12)
    ops.node( 6,  5 * 12, 10 * 12)
    ops.node( 7,  6 * 12, 10 * 12)
    ops.node( 8,  7 * 12, 10 * 12)
    ops.node( 9,  8 * 12, 10 * 12)
    ops.node(10,  9 * 12, 10 * 12)
    ops.node(11, 10 * 12, 10 * 12)
    ops.node(12,  0 * 12,  0 * 12) # L. column
    ops.node(13,  0 * 12,  1 * 12)
    ops.node(14,  0 * 12,  2 * 12)
    ops.node(15,  0 * 12,  3 * 12)
    ops.node(16,  0 * 12,  4 * 12)
    ops.node(17,  0 * 12,  5 * 12)
    ops.node(18,  0 * 12,  6 * 12)
    ops.node(19,  0 * 12,  7 * 12)
    ops.node(20,  0 * 12,  8 * 12)
    ops.node(21,  0 * 12,  9 * 12)
    ops.node(22, 10 * 12,  0 * 12) # R. column
    ops.node(23, 10 * 12,  1 * 12)
    ops.node(24, 10 * 12,  2 * 12)
    ops.node(25, 10 * 12,  3 * 12)
    ops.node(26, 10 * 12,  4 * 12)
    ops.node(27, 10 * 12,  5 * 12)
    ops.node(28, 10 * 12,  6 * 12)
    ops.node(29, 10 * 12,  7 * 12)
    ops.node(30, 10 * 12,  8 * 12)
    ops.node(31, 10 * 12,  9 * 12)

    # Define the boundary conditions:
    ops.fix(12, 1, 1, 1)
    ops.fix(22, 1, 1, 1)

    # Define the cross-sectional properties:
    ops.section("Elastic", 1, E, A_g_B, I_x_B) # Beam
    ops.section("Elastic", 2, E, A_g_C, I_x_C) # Columns

    # Define the transformation:
    ops.geomTransf("PDelta", 1)

    # Define the elements:
    ops.element("elasticBeamColumn",  1,  1,  2, 1, 1) # Beam
    ops.element("elasticBeamColumn",  2,  2,  3, 1, 1)
    ops.element("elasticBeamColumn",  3,  3,  4, 1, 1)
    ops.element("elasticBeamColumn",  4,  4,  5, 1, 1)
    ops.element("elasticBeamColumn",  5,  5,  6, 1, 1)
    ops.element("elasticBeamColumn",  6,  6,  7, 1, 1)
    ops.element("elasticBeamColumn",  7,  7,  8, 1, 1)
    ops.element("elasticBeamColumn",  8,  8,  9, 1, 1)
    ops.element("elasticBeamColumn",  9,  9, 10, 1, 1)
    ops.element("elasticBeamColumn", 10, 10, 11, 1, 1)
    ops.element("elasticBeamColumn", 11, 12, 13, 2, 1) # L. column
    ops.element("elasticBeamColumn", 12, 13, 14, 2, 1)
    ops.element("elasticBeamColumn", 13, 14, 15, 2, 1)
    ops.element("elasticBeamColumn", 14, 15, 16, 2, 1)
    ops.element("elasticBeamColumn", 15, 16, 17, 2, 1)
    ops.element("elasticBeamColumn", 16, 17, 18, 2, 1)
    ops.element("elasticBeamColumn", 17, 18, 19, 2, 1)
    ops.element("elasticBeamColumn", 18, 19, 20, 2, 1)
    ops.element("elasticBeamColumn", 19, 20, 21, 2, 1)
    ops.element("elasticBeamColumn", 20, 21,  1, 2, 1)
    ops.element("elasticBeamColumn", 21, 22, 23, 2, 1) # R. column
    ops.element("elasticBeamColumn", 22, 23, 24, 2, 1)
    ops.element("elasticBeamColumn", 23, 24, 25, 2, 1)
    ops.element("elasticBeamColumn", 24, 25, 26, 2, 1)
    ops.element("elasticBeamColumn", 25, 26, 27, 2, 1)
    ops.element("elasticBeamColumn", 26, 27, 28, 2, 1)
    ops.element("elasticBeamColumn", 27, 28, 29, 2, 1)
    ops.element("elasticBeamColumn", 28, 29, 30, 2, 1)
    ops.element("elasticBeamColumn", 29, 30, 31, 2, 1)
    ops.element("elasticBeamColumn", 30, 31, 11, 2, 1)

    # Define the loads:
    ops.timeSeries("Linear", 1)
    ops.pattern("Plain", 1, 1)
    ops.eleLoad("-ele",  1, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele",  2, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele",  3, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele",  4, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele",  5, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele",  6, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele",  7, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele",  8, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele",  9, "-type", "-beamUniform", w_D)
    ops.eleLoad("-ele", 10, "-type", "-beamUniform", w_D)

    # Define the solver parameters:
    ops.system("BandSPD")
    ops.numberer("RCM")
    ops.constraints("Plain")
    ops.algorithm("Linear")

    # Solve:
    ops.integrator("LoadControl", 1 / NumIncrements)
    ops.analysis("Static")
    ops.analyze(NumIncrements)

    # Get the internal bending moment at each node:
    # ElementForces = [ops.eleForce(i) for i in 1:30]

    # Compute the weight of the structure:
    Weight = ρ * (10 * 120 * A_g_B + 2 * 10 * 120 * A_g_C)

    # Return the result:
    return Weight
end

# Define the constraints:
EnvelopingConstraintsC = float.(XLSX.readxlsx("Enveloping Constraints.xlsx")["Columns"][2:end, :])
A_C = EnvelopingConstraintsC[:, 1:3]
b_C = EnvelopingConstraintsC[:, 4]

EnvelopingConstraintsB = float.(XLSX.readxlsx("Enveloping Constraints.xlsx")["Beams"][2:end, :])
A_B = EnvelopingConstraintsB[:, 1:3]
b_B = EnvelopingConstraintsB[:, 4]

TotalNumEnvelopingConstraints = size(EnvelopingConstraintsC, 1) + size(EnvelopingConstraintsB, 1)
LowerBound = fill(-Inf, TotalNumEnvelopingConstraints)
UpperBound = [b_C; b_B]

function Constraints(res, u, p)
    # Define the enveloping constraints:
    u_C  = u[1:3]       # Columns
    EC_C = A_C * u_C
    u_B  = u[4:6]       # Beams
    EC_B = A_B * u_B

    # Combine the constraints:
    EC = [EC_C; EC_B]

    return (res .= EC)
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
    10.0, 40.0, 20.0, 
    10.0, 80.0, 20.0]
p₀ = [29000, -10 / 12, 490 / 12 ^ 3]

# Solve the optimization problem:
Objective = Optimization.OptimizationFunction(PlanarFrame, Optimization.AutoFiniteDiff(), cons = Constraints)
Problem   = Optimization.OptimizationProblem(Objective, u₀, p₀, 
    lb = [  3.840,    39.600,   11.400,   3.550,    11.300,    6.280],
    ub = [257.000, 18100.000, 2030.000, 272.000, 73000.000, 4130.000],
    lcons = LowerBound, 
    ucons = UpperBound)
Solution  = Optimization.solve(Problem, Ipopt.Optimizer(), callback = Callback; tol = 1E-3)

# Plot the solution:
begin
    F = Figure(size = 72 .* (8, 6))

    A = Axis3(F[1, 1], 
        title  = L"Optimal solution found using the Interior Point Method$$",
        xlabel = L"$A_g$ (in.$^2$)", xlabelrotation = 0,
        ylabel = L"$I_x$ (in.$^4$)", ylabelrotation = 0,
        zlabel = L"$Z_x$ (in.$^3$)", zlabelrotation = π / 2,
        protrusions = 50)

    # Columns:
    SolutionC = Matrix{Float64}(undef, length(Storage), 3)
    for (i, State) in enumerate(Storage)
        SolutionC[i, :] = State[2][1:3]
    end

    scatterlines!(A, SolutionC,
        color      = :black,
        linewidth  = 0.5,
        markersize = 6)

    scatter!(A, (u₀[1:3]...), 
        label       = "Initial guess for columns", 
        color       = :crimson, 
        marker      = :circle, 
        strokecolor = :black, 
        strokewidth = 1,
        overdraw    = true)

    scatter!(A, (Solution.u[1:3]...), 
        label       = "Optimal solution for columns", 
        color       = :crimson, 
        marker      = :rect, 
        strokecolor = :black, 
        strokewidth = 1,
        overdraw    = true)

    # Beams:
    SolutionB = Matrix{Float64}(undef, length(Storage), 3)
    for (i, State) in enumerate(Storage)
        SolutionB[i, :] = State[2][4:6]
    end

    scatterlines!(A, SolutionB,
        color      = :black,
        linewidth  = 0.5,
        markersize = 6)

    scatter!(A, (u₀[4:6]...),
        label       = "Initial guess for beams", 
        color       = :steelblue, 
        marker      = :circle, 
        strokecolor = :black, 
        strokewidth = 1,
        overdraw    = true)

    scatter!(A, (Solution.u[4:6]...), 
        label       = "Optimal solution for beams", 
        color       = :steelblue, 
        marker      = :rect, 
        strokecolor = :black, 
        strokewidth = 1,
        overdraw    = true)

    # axislegend(A, position = :rt, nbanks = 2)
    Legend(F[2, 1], A, nbanks = 2, tellheight = true, tellwidth = false, framevisible = false)

    display(F)
end

# Save the plot:
save("OptimalSolution.png", F)