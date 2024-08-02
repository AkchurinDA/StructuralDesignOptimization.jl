# Preamble:
import XLSX
import Polyhedra
import GLPK
using GLMakie, MathTeXEngine

# Load the data:
AISCSectionDatabase = XLSX.readxlsx("AISC Section Database.xlsx")["Sections"]

# Extract the data:
SectionProperties = float.(hcat(
    AISCSectionDatabase[ "E"][2:end],
    AISCSectionDatabase["AL"][2:end],
    AISCSectionDatabase["AM"][2:end]))

# Create the convex hull:
CH = Polyhedra.convexhull([Vector(x) for x in eachrow(SectionProperties)]...)
CH = Polyhedra.removevredundancy(CH, GLPK.Optimizer)

# Convert the convex hull to a polyhedron:
P = Polyhedra.polyhedron(CH)

# Extract the V-representation and H-representation of the polyhedron:
PolyhedronV = Polyhedra.vrep(P) # V-representation
PolyhedronH = Polyhedra.hrep(P) # H-representation

# Create a mesh of the convex hull:
ConvexHullMesh = Polyhedra.Mesh{3}(P)

# Plot the convex hull:
begin
    F = Figure(fonts = (; regular = texfont()))

    A = Axis3(F[1, 1],
        xlabel = L"A",
        ylabel = L"I_{xx}",
        zlabel = L"Z_{xx}")

    scatter!(A, SectionProperties, 
        color      = :black,
        markersize = 3)

    mesh!(A, ConvexHullMesh,
        color = (:deepskyblue, 0.5))

    wireframe!(A, ConvexHullMesh, 
        color     = (:black, 0.5),
        linewidth = 0.5)

    display(F)
end