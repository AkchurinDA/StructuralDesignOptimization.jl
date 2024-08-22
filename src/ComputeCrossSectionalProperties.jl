function compute_A_g(d, b_f, t_f, t_w)
    A_g = b_f * d - 2 * (b_f - t_w) * (d - 2 * t_f)

    return A_g
end

function compute_I_xx(d, b_f, t_f, t_w)
    I_xx = b_f * d ^ 3 / 12 - (b_f - t_w) * (d - 2 * t_f) ^ 3 / 12

    return I_xx
end

function compute_Z_xx(d, b_f, t_f, t_w)
    Z_xx = b_f * t_f * (d - t_f) + t_w * (d - 2 * t_f) ^ 2 / 4

    return Z_xx
end