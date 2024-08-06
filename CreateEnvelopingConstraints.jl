# Preamble:
import XLSX, DataFrames
import Polyhedra, GLPK
import LinearAlgebra
using CairoMakie, MathTeXEngine
CairoMakie.activate!(type = :png, px_per_unit = 5)
set_theme!(theme_latexfonts())

# Load the data:
SectionDatabase = DataFrames.DataFrame(XLSX.readtable("Section Database.xlsx", "Sections"))

# Extract the data:
A_g = float.(SectionDatabase[:, :A_g])
I_x = float.(SectionDatabase[:, :I_x])
Z_x = float.(SectionDatabase[:, :Z_x])
S_x = float.(SectionDatabase[:, :S_x])
I_y = float.(SectionDatabase[:, :I_y])
Z_y = float.(SectionDatabase[:, :Z_y])
S_y = float.(SectionDatabase[:, :S_y])

# Define the section properties of interest:
SectionProperties = [A_g I_x Z_x]

# Take the logarithm of the section properties:
SectionProperties = log.(SectionProperties)

# --------------------------------------------------
# CONVEX HULL
# --------------------------------------------------
# Create the convex hull:
ConvexHull = Polyhedra.convexhull([Vector(x) for x in eachrow(SectionProperties)]...)

# Remove redundant vertices from the convex hull:
ConvexHull = Polyhedra.removevredundancy(ConvexHull, GLPK.Optimizer)

# Convert the convex hull to a polyhedron:
Polyhedron = Polyhedra.polyhedron(ConvexHull)

# Create a mesh of the polyhedron:
PolyhedronMesh = Polyhedra.Mesh{3}(Polyhedron)
Polyhedra.fulldecompose!(PolyhedronMesh)

# --------------------------------------------------
# REDUCED CONVEX HULL
# --------------------------------------------------
# Extract the vertices and half-spaces of the reduced convex hull:
Vertices   = ConvexHull.points
HalfSpaces = Polyhedron.hrep.halfspaces

# Convert the half-spaces to hyper-planes:
HyperPlanes = [Polyhedra.HyperPlane(HalfSpace.a, HalfSpace.β) for HalfSpace in HalfSpaces]

# Create a list of vertices belonging to the hyperplanes of each half-space:
HyperPlaneVertices = []
for HyperPlane in HyperPlanes
    a = HyperPlane.a
    β = HyperPlane.β

    Temporary = []
    for Vertex in Vertices
        if LinearAlgebra.dot(a, Vertex) ≈ β atol = 1E-12
            push!(Temporary, Vertex)
        end
    end

    push!(HyperPlaneVertices, Temporary)
end

# Make sure that each hyper-plane is composed of exactly three vertices:
if !all(length.(HyperPlaneVertices) .== 3)
    error("Each hyper-plane must be composed of exactly three vertices.")
end

# Compute the area of each face:
ComputeArea(P₁, P₂, P₃) = 0.5 * LinearAlgebra.norm(LinearAlgebra.cross(P₂ - P₁, P₃ - P₁))
Areas = [ComputeArea(HyperPlaneVertices[i]...) for i in eachindex(HyperPlaneVertices)]

# Sort the half-spaces by area:
SortingIndex = sortperm(Areas, rev = true)
SortedHalfSpaces = HalfSpaces[SortingIndex]

# Keep only the top N half-spaces:
N = 25
ReducedHalfSpaces = SortedHalfSpaces[1:N]

# Create a new polyhedron:
ReducedPolyhedron = Polyhedra.polyhedron(Polyhedra.hrep(ReducedHalfSpaces))

# Create a mesh of the polyhedron:
ReducedPolyhedronMesh = Polyhedra.Mesh{3}(ReducedPolyhedron)
Polyhedra.fulldecompose!(ReducedPolyhedronMesh)

# --------------------------------------------------
# ENVELOPING CONSTRAINTS
# --------------------------------------------------
# Define the enveloping constraints:
EnvelopingConstraints = ReducedHalfSpaces
a = getfield.(EnvelopingConstraints, :a)
β = getfield.(EnvelopingConstraints, :β)

# --------------------------------------------------
# PLOT
# --------------------------------------------------
begin
    F = Figure(size = 72 .* (12, 6))

    A = Axis3(F[1, 1],
        title          = L"Convex hull\\ %$(Polyhedra.nhalfspaces(Polyhedron)) enveloping constraints, $V = %$(round(Polyhedra.volume(Polyhedron), digits = 3))$",
        xlabel         = L"$\log_{10}{(A_{g})}$",
        ylabel         = L"$\log_{10}{(I_{x})}$",
        zlabel         = L"$\log_{10}{(Z_{x})}$",
        xlabelrotation = 0,
        ylabelrotation = 0,
        zlabelrotation = π / 2,
        zlabeloffset   = 30,
        xticks         = 1:7,
        yticks         = 1:12,
        zticks         = 1:9,
        protrusions    = 50,
        limits         = (0, 7, 0, 12, 0, 9),
        aspect         = :data,
        azimuth        = π / 4, 
        elevation      = π / 12)

    # Plot the section properties (projections):
    scatter!(A, [zeros(size(SectionProperties, 1), 1) SectionProperties[:, 2] SectionProperties[:, 3]], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    scatter!(A, [SectionProperties[:, 1] zeros(size(SectionProperties, 1), 1) SectionProperties[:, 3]], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    scatter!(A, [SectionProperties[:, 1] SectionProperties[:, 2] zeros(size(SectionProperties, 1), 1)], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    # Plot the convex hull:
    scatter!(A, SectionProperties,
        color      = :black,
        alpha      = 0.25,
        markersize = 3)

    mesh!(A, PolyhedronMesh,
        color = :deepskyblue,
        alpha = 0.25)

    wireframe!(A, PolyhedronMesh,
        color     = :black,
        alpha     = 0.25,
        linewidth = 0.50)

        A = Axis3(F[1, 2],
        title          = L"Reduced convex hull\\ %$(Polyhedra.nhalfspaces(ReducedPolyhedron)) enveloping constraints, $V = %$(round(Polyhedra.volume(ReducedPolyhedron), digits = 3))$",
        xlabel         = L"$\log_{10}{(A_{g})}$", 
        ylabel         = L"$\log_{10}{(I_{x})}$",
        zlabel         = L"$\log_{10}{(Z_{x})}$",
        xlabelrotation = 0,
        ylabelrotation = 0,
        zlabelrotation = π / 2,
        zlabeloffset   = 30,
        xticks         = 1:7,
        yticks         = 1:12,
        zticks         = 1:9,
        protrusions    = 50,
        limits         = (0, 7, 0, 12, 0, 9),
        aspect         = :data,
        azimuth        = π / 4, 
        elevation      = π / 12)

    # Plot the section properties (projections):
    scatter!(A, [zeros(size(SectionProperties, 1), 1) SectionProperties[:, 2] SectionProperties[:, 3]], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    scatter!(A, [SectionProperties[:, 1] zeros(size(SectionProperties, 1), 1) SectionProperties[:, 3]], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    scatter!(A, [SectionProperties[:, 1] SectionProperties[:, 2] zeros(size(SectionProperties, 1), 1)], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    # Plot the convex hull:
    scatter!(A, SectionProperties,
        color      = :black,
        alpha      = 0.25,
        markersize = 3)

    mesh!(A, ReducedPolyhedronMesh,
        color = :deepskyblue,
        alpha = 0.25)

    wireframe!(A, ReducedPolyhedronMesh,
        color     = :black,
        alpha     = 0.25,
        linewidth = 0.50)

    display(F)
end

# Save the plot:
save("ConvexHulls.png", F)