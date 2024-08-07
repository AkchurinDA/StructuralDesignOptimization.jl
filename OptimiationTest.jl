import Optimization, OptimizationMOI, Ipopt, FiniteDiff

Rosenbrock(u, p) = (p[1] - u[1]) ^ 2 + p[2] * (u[2] - u[1]^2) ^ 2
u₀ = [1.0, 1.0]
p₀ = [1.0, 1.0]

function Constraints(res, u, p)
    Constraint₁ = u[1] ^ 2 + u[2] ^ 2
    Constraint₂ = u[1] * u[2]

    return (res .= [Constraint₁, Constraint₂])
end

Storage = []
function Callback(s, l)
    # Extract the state of the optimization problem:
    CurrentState = [s.iter, s.u, s.objective]

    # Store the state of the optimization problem:
    push!(Storage, deepcopy(CurrentState))

    return false
end

Objective = Optimization.OptimizationFunction(Rosenbrock, Optimization.AutoFiniteDiff(), cons = Constraints)
Problem   = Optimization.OptimizationProblem(Objective, u₀, p₀, lcons = [-Inf, -1.0], ucons = [0.8, 2.0])
Solution  = Optimization.solve(Problem, Ipopt.Optimizer(), callback = Callback; tol = 1E-3)