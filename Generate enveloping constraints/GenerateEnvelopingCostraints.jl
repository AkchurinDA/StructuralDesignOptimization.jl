# Preamble:
import XLSX
import DataFrames
import Polyhedra
import GLPK
import LinearAlgebra

# Load the appropriate (non-slender in compression and compact in flexure) sections::
appropriate_sections_C = DataFrames.DataFrame(XLSX.readtable("Identify appropriate sections/Sections.xlsx", "Appropriate sections (C)"))
appropriate_sections_B = DataFrames.DataFrame(XLSX.readtable("Identify appropriate sections/Sections.xlsx", "Appropriate sections (B)"))

# Extract the cross-sectional dimensions of interest:
d_B   = float.(appropriate_sections_B[:, :d  ])
b_f_B = float.(appropriate_sections_B[:, :b_f])
t_f_B = float.(appropriate_sections_B[:, :t_f])
t_w_B = float.(appropriate_sections_B[:, :t_w])
d_C   = float.(appropriate_sections_C[:, :d  ])
b_f_C = float.(appropriate_sections_C[:, :b_f])
t_f_C = float.(appropriate_sections_C[:, :t_f])
t_w_C = float.(appropriate_sections_C[:, :t_w])

cross_sectional_dimensions_B = [d_B b_f_B t_f_B t_w_B]
cross_sectional_dimensions_C = [d_C b_f_C t_f_C t_w_C]

# Create the convex hulls:
convex_hull_B = Polyhedra.convexhull([Vector(x) for x in eachrow(cross_sectional_dimensions_B)]...)
convex_hull_C = Polyhedra.convexhull([Vector(x) for x in eachrow(cross_sectional_dimensions_C)]...)

# Remove redundant vertices from the convex hull:
convex_hull_B = Polyhedra.removevredundancy(convex_hull_B, GLPK.Optimizer)
convex_hull_C = Polyhedra.removevredundancy(convex_hull_C, GLPK.Optimizer)

# Convert the convex hull to a polyhedron:
polyhedron_B = Polyhedra.polyhedron(convex_hull_B)
polyhedron_C = Polyhedra.polyhedron(convex_hull_C)

# Save enveloping constraints for columns and beams:
halfspaces_B = Polyhedra.hrep(polyhedron_B).halfspaces
enveloping_constraints_B = Matrix{Float64}(undef, length(halfspaces_B), 5)
for (i, HalfSpace) in enumerate(halfspaces_B)
    enveloping_constraints_B[i, 1:4] = HalfSpace.a
    enveloping_constraints_B[i, 5]   = HalfSpace.β
end

halfspaces_C = Polyhedra.hrep(polyhedron_C).halfspaces
enveloping_constraints_C = Matrix{Float64}(undef, length(halfspaces_C), 5)
for (i, HalfSpace) in enumerate(halfspaces_C)
    enveloping_constraints_C[i, 1:4] = HalfSpace.a
    enveloping_constraints_C[i, 5]   = HalfSpace.β
end

enveloping_constraints_C_DF = DataFrames.DataFrame(enveloping_constraints_C, [:a_1, :a_2, :a_3, :a_4, :b])
enveloping_constraints_B_DF = DataFrames.DataFrame(enveloping_constraints_B, [:a_1, :a_2, :a_3, :a_4, :b])

XLSX.writetable("Generate enveloping constraints/Enveloping Constraints.xlsx", "C" => enveloping_constraints_C_DF, "B" => enveloping_constraints_B_DF)