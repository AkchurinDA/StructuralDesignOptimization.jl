# The following function is used to subdivide each element of a model into more element.
function subdivide_elements(OldNodes, OldElements, NumSubdivisions)
    # Preallocate new OldElements:
    NumOldElements = length(OldElements)
    NumNewElements = NumOldElements * NumSubdivisions
    NewElements    = Vector{Tuple}(undef, NumNewElements)

    # Preallocate new OldNodes:
    NumOldNodes = length(OldNodes)
    NumNewNodes = NumOldNodes + NumOldElements * (NumSubdivisions - 1)
    NewNodes    = Vector{Tuple}(undef, NumNewNodes)
    
    # Copy the original OldNodes to preserve the node numbering:
    NewNodes[1:NumOldNodes] = OldNodes

    # Preallocate the node and element maps:
    NodeMap    = Matrix{Int}(undef, NumOldElements, 1 + NumSubdivisions + 1)
    ElementMap = Matrix{Int}(undef, NumOldElements, 1 + NumSubdivisions)

    # Loop over the OldElements:
    NewNodeCounter    = 0
    NewElementCounter = 0
    for (i, Element) in enumerate(OldElements)
        # Extract the node coordinates:
        x_i = OldNodes[Element[2]][2]
        y_i = OldNodes[Element[2]][3]
        x_j = OldNodes[Element[3]][2]
        y_j = OldNodes[Element[3]][3]

        # Compute the coordinates of the intermediate OldNodes to be added:
        x_inter = collect(range(x_i, x_j, length = NumSubdivisions + 1))[2:(end - 1)]
        y_inter = collect(range(y_i, y_j, length = NumSubdivisions + 1))[2:(end - 1)]

        # Define the node and element maps:
        NodeMap[i, :]    = [Element[1], Element[2], collect((NumOldNodes + NewNodeCounter + 1):(NumOldNodes + NewNodeCounter + NumSubdivisions - 1))..., Element[3]]
        ElementMap[i, :] = [Element[1], collect((NewElementCounter + 1):(NewElementCounter + NumSubdivisions))...]

        # Add new OldNodes:
        for j in 1:(NumSubdivisions - 1)
            NewNodes[NumOldNodes + NewNodeCounter + j] = (NumOldNodes + NewNodeCounter + j, x_inter[j], y_inter[j])
        end

        # Add new OldElements:
        for j in 1:NumSubdivisions
            NewElements[NewElementCounter + j] = (NewElementCounter + j, NodeMap[i, j + 1], NodeMap[i, j + 2], Element[4:6]...)
        end

        # Update the node and element counters:
        NewNodeCounter    += NumSubdivisions - 1
        NewElementCounter += NumSubdivisions
    end

    # Return the new OldNodes and OldElements:
    return NewNodes, NewElements, NodeMap, ElementMap
end

# The following function is used to compute each element'S length and orientation.
function compute_element_properties(Nodes, Elements)
    NumElements = length(Elements)

    L = Vector{Float64}(undef, NumElements)
    θ = Vector{Float64}(undef, NumElements)

    for (i, Element) in enumerate(Elements)
        x_i = Nodes[Element[2]][2]
        y_i = Nodes[Element[2]][3]
        x_j = Nodes[Element[3]][2]
        y_j = Nodes[Element[3]][3]

        LTemp = sqrt((x_j - x_i) ^ 2 + (y_j - y_i) ^ 2)
        θTemp = atan((y_j - y_i) / (x_j - x_i))

        L[i] = LTemp
        θ[i] = θTemp
    end

    return L, θ
end

# The following function is used to convert the internal element forces from the global to the local coordinate system.
function convert_element_forces_G2L(Elements, GlobalElementForces, θ)
    NumElements = length(Elements)

    LocalElemntForces = Matrix{Float64}(undef, NumElements, 6)

    for i in eachindex(Elements)
        C = cos(θ[i])
        S = sin(θ[i])

        R = [
            +C +S 0  0  0 0
            -S +C 0  0  0 0
             0  0 1  0  0 0
             0  0 0 +C +S 0
             0  0 0 -S +C 0
             0  0 0  0  0 1]

        LocalElemntForces[i, :] = R * GlobalElementForces[i]
    end

    return LocalElemntForces
end