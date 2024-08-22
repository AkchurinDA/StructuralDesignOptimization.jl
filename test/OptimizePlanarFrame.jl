# Preamble:
import PyCall 
import Optimization 
import OptimizationMOI 
import Ipopt 
import FiniteDiff 
import XLSX 
import StructuralDesignOptimization
using CairoMakie 
CairoMakie.activate!(type = :svg)
CairoMakie.set_theme!(theme_latexfonts())

# Load the OpenSeesPy package:
ops = PyCall.pyimport("openseespy.opensees")

# Define an OpenSeesPy model of a planar frame subjected to gravity loads:
function PlanarFrame(x, p; num_subdivisions = 10, num_steps = 10)
    # --------------------------------------------------
    # USER INPUT
    # --------------------------------------------------
    # Unpack the design variables and parameters:
    d_C, b_f_C, t_f_C, t_w_C, d_B, b_f_B, t_f_B, t_w_B = x
    E, F_y, ρ, 
    ϕ_c, ϕ_t, ϕ_b, 
    γ_D, γ_L, γ_W, 
    P_D, P_L, P_W, 
    w_D, w_L, w_W, 
    τ_b0_C, τ_b0_B = p
    
    # Convert the cross-sectional dimensions of all members into their cross-sectional properties:
    A_g_C  = StructuralDesignOptimization.compute_A_g(d_C, b_f_C, t_f_C, t_w_C)
    I_xx_C = StructuralDesignOptimization.compute_I_xx(d_C, b_f_C, t_f_C, t_w_C)
    A_g_B  = StructuralDesignOptimization.compute_A_g(d_B, b_f_B, t_f_B, t_w_B)
    I_xx_B = StructuralDesignOptimization.compute_I_xx(d_B, b_f_B, t_f_B, t_w_B)

    # Define the nodes:
    # [Node ID, x-coordinate, y-coordinate]
    nodes = [
        (1,  0 * 12, 10 * 12)
        (2, 10 * 12, 10 * 12)
        (3,  0 * 12,  0 * 12)
        (4, 10 * 12,  0 * 12)]
    
    # Define the elements:
    # [Element ID, Node (i) ID, Node (j) ID, Young's modulus, Gross cross-sectional area, Moment of inertia]
    elements = [
        (1, 1, 2, E, A_g_B, I_xx_B)
        (2, 3, 1, E, A_g_C, I_xx_C)
        (3, 4, 2, E, A_g_C, I_xx_C)]

    # Define the boundary conditions:
    boundary_conditions = [
        (3, 1, 1, 1)
        (4, 1, 1, 1)]

    # Define the distributed loads:
    distributed_loads = [
        (1, w_L)]

    # --------------------------------------------------
    # DO NOT MODIFY THE CODE BELOW
    # --------------------------------------------------
    # Subdivide the elements:
    new_nodes, new_elements, _, element_map = StructuralDesignOptimization.subdivide_elements(nodes, elements, num_subdivisions)

    # Compute the element properties of the original elements:
    _, θ = StructuralDesignOptimization.compute_element_properties(new_nodes, new_elements)

    # Remove any previous models:
    ops.wipe()

    # Define the model parameters:
    ops.model("basic", "-ndm", 2, "-ndf", 3)

    # Define the nodes:
    for new_node in new_nodes
        ops.node(new_node...)
    end

    # Define the boundary conditions:
    for boundary_condition in boundary_conditions
        ops.fix(boundary_condition...)
    end

    # Define the cross-sectional properties:
    for new_element in new_elements
        ops.section("Elastic", new_element[1], new_element[4], new_element[5], new_element[6])
    end

    # Define the transformation:
    ops.geomTransf("PDelta", 1)

    # Define the elements:
    for new_element in new_elements
        ops.element("elasticBeamColumn", new_element[1], new_element[2], new_element[3], new_element[1], 1)
    end

    # Define the loads:
    ops.timeSeries("Linear", 1)
    ops.pattern("Plain", 1, 1)
    for distributed_load in distributed_loads
        for i in element_map[distributed_load[1], 2:end]
            ops.eleLoad("-ele", i, "-type", "-beamUniform", distributed_load[2])
        end
    end

    # Define the solver parameters:
    ops.system("BandSPD")
    ops.numberer("RCM")
    ops.constraints("Plain")
    ops.algorithm("Linear")

    # Solve:
    ops.integrator("LoadControl", 1 / num_steps)
    ops.analysis("Static")
    ops.analyze(num_steps)

    # Compute the internal element forces in global coordinates:
    global_element_forces = [ops.eleForce(i) for i in eachindex(new_elements)]

    # Compute the internal element forces in local coordinates:
    local_element_forces = StructuralDesignOptimization.convert_element_forces_G2L(new_elements, global_element_forces, θ)

    # Convert the internal forces to a common sign convention:
    local_element_forces[:, 1:3] = (-1) * local_element_forces[:, 1:3]

    # Extract the internal forces:
    N = zeros(length(elements), 1 + num_subdivisions + 1) # Interal axial forces
    M = zeros(length(elements), 1 + num_subdivisions + 1) # Interal bending moments
    for Element in elements
        N[Element[1], 1] = Element[1]
        M[Element[1], 1] = Element[1]

        for i in 1:num_subdivisions
            N[Element[1], 1 + i] = local_element_forces[element_map[Element[1], 1 + i], 1]
            M[Element[1], 1 + i] = local_element_forces[element_map[Element[1], 1 + i], 3]

            if i == num_subdivisions
                N[Element[1], 1 + i + 1] = local_element_forces[element_map[Element[1], 1 + i], 4]
                M[Element[1], 1 + i + 1] = local_element_forces[element_map[Element[1], 1 + i], 6]
            end
        end
    end

    # Compute the required strengths:
    M_r = Float64[]
    P_r = Float64[]
    for Element in elements
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
enveloping_constraints_B = float.(XLSX.readxlsx("Enveloping constraints.xlsx")["Beams"][2:end, :])
Ξ_B = enveloping_constraints_B[:, 1:3]
ξ_B = enveloping_constraints_B[:, 4]

enveloping_constraints_C = float.(XLSX.readxlsx("Enveloping constraints.xlsx")["Columns"][2:end, :])
Ξ_C = enveloping_constraints_C[:, 1:3]
ξ_C = enveloping_constraints_C[:, 4]

total_num_enveloping_constraints = size(enveloping_constraints_C, 1) + size(enveloping_constraints_B, 1)
lower_bound = [fill(-Inf, total_num_enveloping_constraints); 0; 0; 0]
upper_bound = [ξ_B; ξ_C; 1; 1; 1]

function constraints(res, u, p)
    # Define the enveloping constraints:
    enveloping_constraints_B = Ξ_B * u[1:3]
    enveloping_constraints_C = Ξ_C * u[4:6]
    
    # Define the strength constraints:
    P_r, M_r = PlanarFrame(u, p)

    # Compute the design strengths for all members:
    if P_r[1] < 0
        P_c_1 = StructuralDesignOptimization.compute_P_n_c(0.90, 29000, 50, 1, 120, u[1:2]...)
    else
        P_c_1 = StructuralDesignOptimization.compute_P_n_t(0.90, 50, u[1])
    end

    if P_r[2] < 0
        P_c_2 = StructuralDesignOptimization.compute_P_n_c(0.90, 29000, 50, 1, 120, u[4:5]...)
    else
        P_c_2 = StructuralDesignOptimization.compute_P_n_t(0.90, 50, u[4])
    end

    if P_r[3] < 0
        P_c_3 = StructuralDesignOptimization.compute_P_n_c(0.90, 29000, 50, 1, 120, u[4:5]...)
    else
        P_c_3 = StructuralDesignOptimization.compute_P_n_t(0.90, 50, u[4])
    end

    M_c_1 = StructuralDesignOptimization.compute_M_n(0.90, 50, u[3])
    M_c_2 = StructuralDesignOptimization.compute_M_n(0.90, 50, u[6])
    M_c_3 = StructuralDesignOptimization.compute_M_n(0.90, 50, u[6])

    # Define the stress constraints:
    strength_constraints = [
        StructuralDesignOptimization.compute_beam_column_interaction(abs(P_r[1]), P_c_1, abs(M_r[1]), M_c_1, 0, 1)
        StructuralDesignOptimization.compute_beam_column_interaction(abs(P_r[2]), P_c_2, abs(M_r[2]), M_c_2, 0, 1)
        StructuralDesignOptimization.compute_beam_column_interaction(abs(P_r[3]), P_c_3, abs(M_r[3]), M_c_3, 0, 1)]

    # Combine the constraints:
    combined_constraints = [enveloping_constraints_B; enveloping_constraints_C; strength_constraints]

    return (res .= combined_constraints)
end

# Define the callback function:
Storage = []
function callback(s, l)
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
Objective = Optimization.OptimizationFunction((u, p) -> p[2] * (120 * u[1] + 2 * 120 * u[4]), Optimization.AutoFiniteDiff(), cons = constraints)
Problem   = Optimization.OptimizationProblem(Objective, u₀, p₀, 
    lb = [  3.840,    39.600,   11.400,   3.550,    11.300,    6.280],
    ub = [257.000, 18100.000, 2030.000, 272.000, 73000.000, 4130.000],
    lcons = lower_bound, 
    ucons = upper_bound)
Solution  = Optimization.solve(Problem, Ipopt.Optimizer(), callback = callback; tol = 1E-3, acceptable_tol = 1E-3, max_iter = 100)

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