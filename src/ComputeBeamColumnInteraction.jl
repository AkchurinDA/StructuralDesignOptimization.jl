# NOTE: Refer to Chapter H of the AISC 360-22 Specification for more information.
function compute_beam_column_interaction(P_r, P_c, M_r_x, M_c_x, M_r_y, M_c_y)
    # Compute the beam-column interaction:
    BeamColumnInteraction = if P_r / P_c ≥ 0.2
        (P_r / P_c) + (8 / 9) * ((M_r_x / M_c_x) + (M_r_y / M_c_y))
    else
        (P_r / (2 * P_c)) + ((M_r_x / M_c_x) + (M_r_y / M_c_y))
    end

    # Return the result:
    return BeamColumnInteraction
end