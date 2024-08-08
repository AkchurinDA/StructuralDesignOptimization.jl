function ComputeDesignCompressiveStrength(ϕ_c, E, F_y, K, L, A_g, I_x)
    # Compute the radius of gyration:
    r = sqrt(I_x / A_g)

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

    # Compute the design compressive strength:
    P_c = ϕ_c * P_n

    # Return the result:
    return P_c
end

function ComputeDesignFlexuralStrength(ϕ_b, F_y, Z_x)
    # Compute the nominal flexural strength:
    M_n = F_y * Z_x

    # Compute the design flexural strength:
    M_c = ϕ_b * M_n

    # Return the result:
    return M_c
end