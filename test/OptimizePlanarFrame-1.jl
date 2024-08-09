# AUTHOR:               Damir Akchurin
# DATE CREATED:         08/07/2024
# DATE LAST MODIFIED:   08/08/2024

# Preamble:
import Optimization                 # V3.27.0
import OptimizationMOI              # V0.4.2
import Ipopt                        # V1.6.5
import FiniteDiff                   # V2.23.1
import XLSX                         # V0.10.1
import StructuralDesignOptimization # Under development
using CairoMakie                    # V0.12.5
CairoMakie.activate!(type = :png, px_per_unit = 5)
set_theme!(theme_latexfonts())

# Define the constraints:
EnvelopingConstraintsB = float.(XLSX.readxlsx("Enveloping Constraints.xlsx")["Beams"][2:end, :])
Ξ_B = EnvelopingConstraintsB[:, 1:3]
ξ_B = EnvelopingConstraintsB[:, 4]

EnvelopingConstraintsC = float.(XLSX.readxlsx("Enveloping Constraints.xlsx")["Columns"][2:end, :])
Ξ_C = EnvelopingConstraintsC[:, 1:3]
ξ_C = EnvelopingConstraintsC[:, 4]

TotalNumEnvelopingConstraints = size(EnvelopingConstraintsC, 1) + size(EnvelopingConstraintsB, 1)
LowerBound = fill(-Inf, TotalNumEnvelopingConstraints)
UpperBound = [ξ_B; ξ_C]

function Constraints(res, u, p)
    # Define the enveloping constraints:
    EC_B = Ξ_B * u[1:3]
    EC_C = Ξ_C * u[4:6]

    # Combine the constraints:
    AllConstraints = [EC_B; EC_C]

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
    20.0, 450.0, 40.0, 
    10.0,  40.0, 15.0]
p₀ = [-10 / 12, 490 / 12 ^ 3, 10, 10]

# Solve the optimization problem:
Objective = Optimization.OptimizationFunction((u, p) -> p[2] * (120 * u[1] + 2 * 120 * u[4]), Optimization.AutoFiniteDiff(), cons = Constraints)
Problem   = Optimization.OptimizationProblem(Objective, u₀, p₀, 
    lb = [  3.840,    39.600,   11.400,   3.550,    11.300,    6.280],
    ub = [257.000, 18100.000, 2030.000, 272.000, 73000.000, 4130.000],
    lcons = LowerBound, 
    ucons = UpperBound)
Solution  = Optimization.solve(Problem, Ipopt.Optimizer(), callback = Callback; tol = 1E-3, acceptable_tol = 1E-3, max_iter = 100)

# Plot the solution:
begin
    F = Figure(size = 72 .* (12, 6), fontsize = 16)

    A = Axis3(F[1, 1],
        xlabel         = L"$A_g$ (in.$^2$)", 
        xlabelrotation = 0,
        ylabel         = L"$I_x$ (in.$^4$)", 
        ylabelrotation = 0,
        zlabel         = L"$Z_x$ (in.$^3$)", 
        zlabelrotation = π / 2,
        protrusions    = 75,
        aspect         = (1, 1, 1 / 2),
        azimuth        = π / 6,
        elevation      = π / 9)

    # Columns:
    SolutionC = Matrix{Float64}(undef, length(Storage), 3)
    for (i, State) in enumerate(Storage)
        SolutionC[i, :] = State[2][1:3]
    end

    lines!(A, SolutionC,
        color      = :crimson,
        linewidth  = 1)

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

    lines!(A, SolutionB,
        color      = :deepskyblue,
        linewidth  = 1)

    scatter!(A, (u₀[4:6]...),
        label       = "Initial guess for beams", 
        color       = :deepskyblue, 
        marker      = :circle, 
        strokecolor = :black, 
        strokewidth = 1,
        overdraw    = true)

    scatter!(A, (Solution.u[4:6]...), 
        label       = "Optimal solution for beams", 
        color       = :deepskyblue, 
        marker      = :rect, 
        strokecolor = :black, 
        strokewidth = 1,
        overdraw    = true)

    axislegend(A, position = :ct, nbanks = 2)

    A = Axis(F[1, 2],
        xlabel = L"Iteration, $i$",
        ylabel = L"Weight, $W$ (lb)",
        limits = (0, (length(Storage) - 1), 0, nothing),
        aspect = 4 / 3)

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

    # display(F)
end

# Save the plot:
save("figures/OptimalSolution-1.png", F)