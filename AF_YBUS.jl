# ===========================================
# Function to calculate the admittance matrix
# ===========================================
function Calculate_Ybus(DBUS::DataFrame, DCIR::DataFrame, nBUS::Int64, nCIR::Int64, base_MVA::Float64)
    # In MATPOWER and POWERMODELS, the TAP and SHIFT of the transformers are treated as "from" to "to"
    # This is the reason why they divide by TAP and not multiply when building the Ybus matrix
    # This approach is different from the one use during my undergraduate studies

    Ybus = zeros(ComplexF64, nBUS, nBUS);   # Initialize the admittance matrix

    # Calculate the admittance matrix including the line data
    for i = 1:nCIR
        k = DCIR.from_bus[i] # Index from bus
        m = DCIR.to_bus[i]   # Index to bus
        if DCIR.l_status[i] == true

            ykm = 1 / (DCIR.l_res[i] + 1im*DCIR.l_reac[i]) # Series admittance
            bkm_sh = DCIR.l_sh_susp[i] / 2                 # Shunt admittance

            t_shift = deg2rad(DCIR.t_shift[i])

            # Ybus[k,k] = Ybus[k,k] + ((DCIR.t_tap[i]^2) * ykm)+ (1im * bkm_sh)
            # Ybus[k,m] = Ybus[k,m] - (DCIR.t_tap[i] * ykm * exp(-1im * t_shift))
            # Ybus[m,k] = Ybus[m,k] - (DCIR.t_tap[i] * ykm * exp(1im * t_shift))
            # Ybus[m,m] = Ybus[m,m] + ykm + (1im * bkm_sh)

            Ybus[k,k] = Ybus[k,k] + ((1/DCIR.t_tap[i])^2 * ykm)+ (1im * bkm_sh)
            Ybus[k,m] = Ybus[k,m] - ((1/DCIR.t_tap[i]) * ykm * exp(1im * t_shift))
            Ybus[m,k] = Ybus[m,k] - ((1/DCIR.t_tap[i]) * ykm * exp(-1im * t_shift))
            Ybus[m,m] = Ybus[m,m] + ykm + (1im * bkm_sh)
        end
    end

    # Include the shunt components of the nodes
    for i = 1:nBUS
        Ybus[i,i] = Ybus[i,i] + (DBUS.g_sh[i] + 1im * DBUS.b_sh[i]) / base_MVA
    end

    return SparseArrays.sparse(Ybus)
end

# ===================================================================================
# Function that use the advantages of Sparse Method in Julia (it also gives the Ybus)
# ===================================================================================
function Calculate_Ybus_sparse(DBUS::DataFrame, DCIR::DataFrame, nBUS::Int64, nCIR::Int64, base_MVA::Float64)
    # In MATPOWER and POWERMODELS, the TAP and SHIFT of the transformers are treated as "from" to "to"
    # This is the reason why they divide by TAP and not multiply when building the Ybus matrix
    # This approach is different from the one use during my undergraduate studies
    row_idx = Int[]
    col_idx = Int[]
    values = ComplexF64[]

    # Add line admittances
    for i in 1:nCIR
        k = DCIR.from_bus[i]
        m = DCIR.to_bus[i]

        if DCIR.l_status[i] == true
            ykm = 1 / (DCIR.l_res[i] + 1im * DCIR.l_reac[i])
            bkm_sh = DCIR.l_sh_susp[i] / 2
            tap = DCIR.t_tap[i]
            shift = deg2rad(DCIR.t_shift[i])

            # Ykk
            push!(row_idx, k)
            push!(col_idx, k)
            # push!(values, (tap^2) * ykm + 1im * bkm_sh)
            push!(values, (1/tap)^2 * ykm + 1im * bkm_sh)

            # Ykm
            push!(row_idx, k)
            push!(col_idx, m)
            # push!(values, -tap * ykm * exp(-1im * shift))
            push!(values, -(1/tap) * ykm * exp(1im * shift))

            # Ymk
            push!(row_idx, m)
            push!(col_idx, k)
            # push!(values, -tap * ykm * exp(1im * shift))
            push!(values, -(1/tap) * ykm * exp(-1im * shift))

            # Ymm
            push!(row_idx, m)
            push!(col_idx, m)
            push!(values, ykm + 1im * bkm_sh)
        end
    end

    # Add shunt admittances from DBUS
    for i in 1:nBUS
        if DBUS.g_sh[i] != 0 || DBUS.b_sh[i] != 0
            push!(row_idx, i)
            push!(col_idx, i)
            push!(values, (DBUS.g_sh[i] + 1im * DBUS.b_sh[i]) / base_MVA)
        end
    end

    # Create the sparse matrix
    Ybus = sparse(row_idx, col_idx, values, nBUS, nBUS)
    return Ybus
end

