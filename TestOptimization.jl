# AUTHOR:               Damir Akchurin
# DATE CREATED:         08/06/2024
# DATE LAST MODIFIED:   08/07/2024

# Preamble:
import Optimization     #V3.27.0
import OptimizationMOI  #V0.4.2
import Ipopt            #V1.6.5
import FiniteDiff       #V2.23.1

# Define the Rosenbrock function:
Rosenbrock(u, p) = (p[1] - u[1]) ^ 2 + p[2] * (u[2] - u[1]^2) ^ 2

# Define the initial values:
u₀ = [100.0, 100.0]
p₀ = [1.0, 1.0]

# Define the constraints:
function Constraints(res, u, p)
    Constraint₁ = u[1] ^ 2 + u[2] ^ 2
    Constraint₂ = u[1] * u[2]

    return (res .= [Constraint₁, Constraint₂])
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

# Solve the optimization problem:
Objective = Optimization.OptimizationFunction(Rosenbrock, Optimization.AutoFiniteDiff(), cons = Constraints)
Problem   = Optimization.OptimizationProblem(Objective, u₀, p₀, lcons = [-Inf, -1.0], ucons = [0.8, 2.0])
Solution  = Optimization.solve(Problem, Ipopt.Optimizer(), callback = Callback; tol = 1E-3)