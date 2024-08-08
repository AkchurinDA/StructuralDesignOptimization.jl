# AUTHOR:               Damir Akchurin
# DATE CREATED:         08/06/2024
# DATE LAST MODIFIED:   08/08/2024

# Preamble:
import PyCall                       # V1.96.4
import StructuralDesignOptimization # Under development

# Load the OpenSeesPy package:
ops = PyCall.pyimport("openseespy.opensees")

# Define an OpenSeesPy model of a planar frame subjected to gravity loads:
function PlanarFrame(u, p)
    # --------------------------------------------------
    # USER INPUT
    # --------------------------------------------------
    # Unpack the design variables and parameters:
    A_g_B, A_g_C, I_x_B, I_x_C, Z_x_B, Z_x_C = u
    w_D, ρ, NumSubdivisions, NumSteps = p

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

    # Compute the weight of the structure:
    Weight = ρ * (10 * 12 * A_g_B + 2 * 10 * 12 * A_g_C)

    # Return the result:
    return Weight, P_r, M_r
end

# Run the model:
Weight, P_r, M_r = PlanarFrame((10, 10, 100, 100, 0, 0), (-10 / 12, 490 / 12 ^ 3, 10, 10))
