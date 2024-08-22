# NOTE: Refer to Chapter D of the AISC 360-22 Specification for more information.
function compute_P_n_t(
        F_y,    # Material properties
        A_g     # Cross-sectional properties
    )
    # Compute the nominal tensile strength:
    P_n = F_y * A_g

    # Return the result:
    return P_n
end

# NOTE: Refer to Chapter E of the AISC 360-22 Specification for more information.
function compute_P_n_c(
        E, F_y,     # Material properties
        K, L,       # Member properties
        A_g, I_xx   # Cross-sectional properties
    )
    # Compute the radius of gyration:
    r = sqrt(I_xx / A_g)

    # Compute the slenderness ratio:
    λ = (K * L) / r

    # Compute the elastic buckling stress:
    F_e = (π ^ 2 * E) / λ ^ 2

    # Compute the nominal stress:
    F_n = if F_y / F_e ≤ 2.25
        (0.658 ^ (F_y / F_e)) * F_y
    else
        0.877 * F_e
    end

    # Compute the nominal compressive strength:
    P_n = F_n * A_g

    # Return the result:
    return P_n
end

# NOTE: Refer to Chapter F of the AISC 360-22 Specification for more information.
function compute_M_n(
        F_y,    # Material properties
        Z       # Cross-sectional properties
    )
    # Compute the nominal flexural strength:
    M_n = F_y * Z

    # Return the result:
    return M_n
end