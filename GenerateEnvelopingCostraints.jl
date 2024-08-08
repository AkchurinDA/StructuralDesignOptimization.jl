# AUTHOR:               Damir Akchurin
# DATE CREATED:         08/07/2024
# DATE LAST MODIFIED:   08/07/2024

# Preamble:
import XLSX             # V0.10.1
import DataFrames       # V1.6.1
import Polyhedra        # V0.7.8
import GLPK             # V1.2.1
import LinearAlgebra    # Standard library
using CairoMakie        # V0.12.5
CairoMakie.activate!(type = :png, px_per_unit = 5)
set_theme!(theme_latexfonts())

# Load the appropriate (non-slender in compression and compact in flexure) sections:
AppropriateSectionDatabase = DataFrames.DataFrame(XLSX.readtable("Appropriate Section Database.xlsx", "Appropriate sections"))
SectionNames               = string.(AppropriateSectionDatabase[:, :Section])

# Define sets of appropriate sections for columns and beams:
AppropriateSectionsC = AppropriateSectionDatabase[90:161, :]
AppropriateSectionsB = AppropriateSectionDatabase

# Extract the section properties of interest:
A_g_C = float.(AppropriateSectionsC[:, :A])
I_x_C = float.(AppropriateSectionsC[:, :I_x])
Z_x_C = float.(AppropriateSectionsC[:, :Z_x])
A_g_B = float.(AppropriateSectionsB[:, :A])
I_x_B = float.(AppropriateSectionsB[:, :I_x])
Z_x_B = float.(AppropriateSectionsB[:, :Z_x])

SectionPropertiesC = [A_g_C I_x_C Z_x_C]
SectionPropertiesB = [A_g_B I_x_B Z_x_B]

# Take the logarithm of the section properties:
SectionPropertiesC = log.(SectionPropertiesC)
SectionPropertiesB = log.(SectionPropertiesB)

# Create the convex hulls:
ConvexHullC = Polyhedra.convexhull([Vector(x) for x in eachrow(SectionPropertiesC)]...)
ConvexHullB = Polyhedra.convexhull([Vector(x) for x in eachrow(SectionPropertiesB)]...)

# Remove redundant vertices from the convex hull:
ConvexHullC = Polyhedra.removevredundancy(ConvexHullC, GLPK.Optimizer)
ConvexHullB = Polyhedra.removevredundancy(ConvexHullB, GLPK.Optimizer)

# Convert the convex hull to a polyhedron:
PolyhedronC = Polyhedra.polyhedron(ConvexHullC)
PolyhedronB = Polyhedra.polyhedron(ConvexHullB)

# NOTE: If you want to save the enveloping constraints to an Excel file, comment out the part where the logaritms of the section properties are taken.
# # Save enveloping constraints for columns and beams:
# HalfSpacesC = Polyhedra.hrep(PolyhedronC).halfspaces
# EnvelopingConstraintsC = Matrix{Float64}(undef, length(HalfSpacesC), 4)
# for (i, HalfSpace) in enumerate(HalfSpacesC)
#     EnvelopingConstraintsC[i, 1:3] = HalfSpace.a
#     EnvelopingConstraintsC[i, 4]   = HalfSpace.β
# end

# HalfSpacesB = Polyhedra.hrep(PolyhedronB).halfspaces
# EnvelopingConstraintsB = Matrix{Float64}(undef, length(HalfSpacesB), 4)
# for (i, HalfSpace) in enumerate(HalfSpacesB)
#     EnvelopingConstraintsB[i, 1:3] = HalfSpace.a
#     EnvelopingConstraintsB[i, 4]   = HalfSpace.β
# end

# EnvelopingConstraintsC_DF = DataFrames.DataFrame(EnvelopingConstraintsC, [:a_1, :a_2, :a_3, :b])
# EnvelopingConstraintsB_DF = DataFrames.DataFrame(EnvelopingConstraintsB, [:a_1, :a_2, :a_3, :b])

# XLSX.writetable("Enveloping Constraints.xlsx", "Columns" => EnvelopingConstraintsC_DF, "Beams" => EnvelopingConstraintsB_DF)

# Create a mesh of the polyhedron:
PolyhedronMeshC = Polyhedra.Mesh{3}(PolyhedronC)
PolyhedronMeshB = Polyhedra.Mesh{3}(PolyhedronB)
Polyhedra.fulldecompose!(PolyhedronMeshC)
Polyhedra.fulldecompose!(PolyhedronMeshB)

# Plot the convex hulls:
begin
    F = Figure(size = 72 .* (12, 6))

    # Columns:
    A_C = Axis3(F[1, 1],
        title = L"Convex hull of section properties for columns \\ %$(Polyhedra.nhalfspaces(PolyhedronC)) enveloping constraints$$",
        xlabel = L"$\log_{10}{(A_g)}$", xlabelrotation = 0,
        ylabel = L"$\log_{10}{(I_x)}$", ylabelrotation = 0,
        zlabel = L"$\log_{10}{(Z_x)}$", zlabelrotation = π / 2,
        protrusions = 60,
        limits = (0, 7, 0, 12, 0, 9),
        aspect = :equal,
        azimuth = π / 6, elevation = π / 12)

    scatter!(A_C, [zeros(size(SectionPropertiesC, 1), 1) SectionPropertiesC[:, 2] SectionPropertiesC[:, 3]], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    scatter!(A_C, [SectionPropertiesC[:, 1] zeros(size(SectionPropertiesC, 1), 1) SectionPropertiesC[:, 3]], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    scatter!(A_C, [SectionPropertiesC[:, 1] SectionPropertiesC[:, 2] zeros(size(SectionPropertiesC, 1), 1)], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    mesh!(A_C, PolyhedronMeshC,
        color = :deepskyblue,
        alpha = 0.25)

    wireframe!(A_C, PolyhedronMeshC,
        color     = :black,
        alpha     = 0.25,
        linewidth = 0.50)

    # Beams:
    A_B = Axis3(F[1, 2],
        title = L"Convex hull of section properties for beams \\ %$(Polyhedra.nhalfspaces(PolyhedronB)) enveloping constraints$$",
        xlabel = L"$\log_{10}{(A_g)}$", xlabelrotation = 0,
        ylabel = L"$\log_{10}{(I_x)}$", ylabelrotation = 0,
        zlabel = L"$\log_{10}{(Z_x)}$", zlabelrotation = π / 2,
        protrusions = 60,
        limits = (0, 7, 0, 12, 0, 9),
        aspect = :equal,
        azimuth = π / 6, elevation = π / 12)

    scatter!(A_B, [zeros(size(SectionPropertiesB, 1), 1) SectionPropertiesB[:, 2] SectionPropertiesB[:, 3]], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    scatter!(A_B, [SectionPropertiesB[:, 1] zeros(size(SectionPropertiesB, 1), 1) SectionPropertiesB[:, 3]], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    scatter!(A_B, [SectionPropertiesB[:, 1] SectionPropertiesB[:, 2] zeros(size(SectionPropertiesB, 1), 1)], 
        color       = :red,
        strokecolor = :black,
        strokewidth = 0.25,
        markersize  = 3)

    mesh!(A_B, PolyhedronMeshB,
        color = :deepskyblue,
        alpha = 0.25)

    wireframe!(A_B, PolyhedronMeshB,
        color     = :black,
        alpha     = 0.25,
        linewidth = 0.50)

    display(F)
end

# Save the plot:
save("ConvexHulls.png", F)