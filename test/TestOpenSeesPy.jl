# AUTHOR:               Damir Akchurin
# DATE CREATED:         08/06/2024
# DATE LAST MODIFIED:   08/07/2024

# Preamble:
import PyCall #V1.96.4

# Load the OpenSeesPy package:
ops = PyCall.pyimport("openseespy.opensees")

# Define an OpenSeesPy model of a planar frame subjected to gravity loads:
function PlanarFrame(x::AbstractVector{<:Real}, p::AbstractVector{<:Real})
    # Unpack the design variables and parameters:
    A_C, A_B, I_C, I_B, Z_C, Z_B = x
    w_D, ρ = p

    # Define the nodes:
    Nodes = []

    # Define the elements:
    Elements = []

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
    ops.section("Elastic", 1, 29000, A_B, I_B) # Beam
    ops.section("Elastic", 2, 29000, A_C, I_C) # Columns

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
    NumSteps = 10
    ops.integrator("LoadControl", 1 / NumSteps)
    ops.analysis("Static")
    ops.analyze(NumSteps)

    # Get the internal bending moment at each node:
    # ElementForces = [ops.eleForce(i) for i in 1:30]

    # Compute the weight of the structure:
    Weight = ρ * (10 * 120 * A_B + 2 * 10 * 120 * A_C)

    # Return the result:
    return Weight
end

# Run the model:
PlanarFrame([10, 10, 100, 100, 0, 0], [-10 / 12, 490 / 12 ^ 3])

