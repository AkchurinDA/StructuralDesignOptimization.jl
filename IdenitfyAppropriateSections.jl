# AUTHOR:               Damir Akchurin
# DATE CREATED:         08/07/2024
# DATE LAST MODIFIED:   08/07/2024

# Preamble:
import XLSX         # V0.10.1
import DataFrames   # V1.6.1

# Define the material properties of interest:
E   = 29000
F_y = 50

# Load all the sections from the AISC Construction Design Manual:
SectionDatabase = DataFrames.DataFrame(XLSX.readtable("Section Database.xlsx", "All sections"))

# Extract the data:
SectionNames = string.(SectionDatabase[:, :Section])
d            = float.(SectionDatabase[:, :d])
b_f          = float.(SectionDatabase[:, :b_f])
t_f          = float.(SectionDatabase[:, :t_f])
t_w          = float.(SectionDatabase[:, :t_w])

# Check the sections:
AppropriateIndex = Vector{Bool}(undef, size(SectionDatabase, 1))
for (i, (d, b_f, t_f, t_w)) in enumerate(zip(d, b_f, t_f, t_w))
    CheckC = CheckSectionC(E, F_y, d, b_f, t_f, t_w)
    CheckF = CheckSectionF(E, F_y, d, b_f, t_f, t_w)

    AppropriateIndex[i] = CheckC && CheckF ? true : false
end

# Extract the appropriate sections:
AppropriateSections = SectionDatabase[AppropriateIndex, :]

# Write the appropriate sections to a new Excel file:
XLSX.writetable("Appropriate Section Database.xlsx", "Appropriate sections" => AppropriateSections)

# Define a function that checks if a section is non-slender in compression:
# NOTE: See Table B4.1a of the AISC 360-22 Specification for more information.
function CheckSectionC(E, F_y, d, b_f, t_f, t_w)
    # Check the flanges:
    λ_r_f = 0.56 * sqrt(E / F_y)
    f     = (b_f / 2) / t_f ≤ λ_r_f ? true : false

    # Check the web:
    λ_r_w = 1.49 * sqrt(E / F_y)
    w     = (d - 2 * t_f) / t_w ≤ λ_r_w ? true : false

    # Check the section:
    s = f && w ? true : false

    # Return the results:
    return s
end

# Define a function that checks if a section is compact in flexure:
# NOTE: See Table B4.1b of the AISC 360-22 Specification for more information.
# NOTE: This function assumes that the flexural load is applied about the major-axis of the section.
function CheckSectionF(E, F_y, d, b_f, t_f, t_w)
    # Check the flanges:
    λ_p_f = 0.38 * sqrt(E / F_y)
    f     = (b_f / 2) / t_f ≤ λ_p_f ? true : false

    # Check the web:
    λ_p_w = 3.76 * sqrt(E / F_y)
    w     = (d - 2 * t_f) / t_w ≤ λ_p_w ? true : false

    # Check the section:
    s = f && w ? true : false

    # Return the results:
    return s
end