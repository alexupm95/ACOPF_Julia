# Function used to Read the Input data from the CSV files and store them into Structs
function Read_Input_Data(folder_path::String)

    # ====================================================================================================
    # If some modification is done in the name of the variables in the CSV files, it must be modified here
    # ==================================================================================================== 

    # Function to read buses data and store in DBUS_Struct
    function read_bus_data()
        df = CSV.read("bus_data.csv", DataFrame; delim=';')  # Read CSV file

        df_bus = deepcopy(df)
        rename!(df_bus, Dict(
            names(df_bus)[1] => :bus,
            names(df_bus)[2] => :type,
            names(df_bus)[3] => :p_d,
            names(df_bus)[4] => :q_d,
            names(df_bus)[5] => :g_sh,
            names(df_bus)[6] => :b_sh,
            names(df_bus)[7] => :area,
            names(df_bus)[8] => :v_spe,
            names(df_bus)[9] => :v_a,
            names(df_bus)[10] => :base_kV,
            names(df_bus)[11] => :zone,
            names(df_bus)[12] => :v_max,
            names(df_bus)[13] => :v_min,
        ))

        df_bus.bus = Int64.(df_bus.bus)
        df_bus.type = Int64.(df_bus.type)
        df_bus.p_d = Float64.(df_bus.p_d)
        df_bus.q_d = Float64.(df_bus.q_d)
        df_bus.g_sh = Float64.(df_bus.g_sh)
        df_bus.b_sh = Float64.(df_bus.b_sh)
        df_bus.area = Int64.(df_bus.area)
        df_bus.v_spe = Float64.(df_bus.v_spe)
        df_bus.v_a = Float64.(df_bus.v_a)
        df_bus.base_kV = Float64.(df_bus.base_kV)
        df_bus.zone = Int64.(df_bus.zone)
        df_bus.v_max = Float64.(df_bus.v_max)
        df_bus.v_min = Float64.(df_bus.v_min)

        return df_bus
    end

    # Function to read generators data and store in DGEN_Struct
    function read_gen_data()
        df = CSV.read("generators_data.csv", DataFrame; delim=';') # Read CSV file
        num_gen = length(df.bus)
        id = collect(1:num_gen)

        df_gen = hcat(DataFrame(id = id), df; makeunique=true)

        rename!(df_gen, Dict(
            names(df_gen)[2] => :bus,
            names(df_gen)[3] => :pg_spe,
            names(df_gen)[4] => :qg_spe,
            names(df_gen)[5] => :qg_max,
            names(df_gen)[6] => :qg_min,
            names(df_gen)[7] => :vg_spe,
            names(df_gen)[8] => :base_MVA,
            names(df_gen)[9] => :g_status,
            names(df_gen)[10] => :pg_max,
            names(df_gen)[11] => :pg_min,
            names(df_gen)[12] => :g_cost_2,
            names(df_gen)[13] => :g_cost_1,
            names(df_gen)[14] => :g_cost_0,
        ))

        df_gen.id = Int64.(df_gen.id)
        df_gen.bus = Int64.(df_gen.bus)
        df_gen.pg_spe = Float64.(df_gen.pg_spe)
        df_gen.qg_spe = Float64.(df_gen.qg_spe)
        df_gen.qg_max = Float64.(df_gen.qg_max)
        df_gen.qg_min = Float64.(df_gen.qg_min)
        df_gen.vg_spe = Float64.(df_gen.vg_spe)
        df_gen.base_MVA = Float64.(df_gen.base_MVA)
        df_gen.g_status = Int64.(df_gen.g_status)
        df_gen.pg_max = Float64.(df_gen.pg_max)
        df_gen.pg_min = Float64.(df_gen.pg_min)
        df_gen.g_cost_2 = Float64.(df_gen.g_cost_2)
        df_gen.g_cost_1 = Float64.(df_gen.g_cost_1)
        df_gen.g_cost_0 = Float64.(df_gen.g_cost_0)
        
        return df_gen
    end

    # Function to read circuits data and store in DCIR_Struct
    function read_circuit_data()
        df = CSV.read("line_data.csv", DataFrame; delim=';')
        num_circ = length(df.fbus)
        id = collect(1:num_circ)

        df_cir = hcat(DataFrame(circ = id), df; makeunique=true)

        rename!(df_cir, Dict(
            names(df_cir)[2] => :from_bus,
            names(df_cir)[3] => :to_bus,
            names(df_cir)[4] => :l_res,
            names(df_cir)[5] => :l_reac,
            names(df_cir)[6] => :l_sh_susp,
            names(df_cir)[7] => :l_cap_1,
            names(df_cir)[8] => :l_cap_2,
            names(df_cir)[9] => :l_cap_3,
            names(df_cir)[10] => :t_tap,
            names(df_cir)[11] => :t_shift,
            names(df_cir)[12] => :l_status,
            names(df_cir)[13] => :ang_min,
            names(df_cir)[14] => :ang_max,
        ))

        df_cir.circ = Int64.(df_cir.circ)
        df_cir.from_bus = Int64.(df_cir.from_bus)
        df_cir.to_bus = Int64.(df_cir.to_bus)
        df_cir.l_res = Float64.(df_cir.l_res)
        df_cir.l_reac = Float64.(df_cir.l_reac)
        df_cir.l_sh_susp = Float64.(df_cir.l_sh_susp)
        df_cir.l_cap_1 = Float64.(df_cir.l_cap_1)
        df_cir.l_cap_2 = Float64.(df_cir.l_cap_2)
        df_cir.l_cap_3 = Float64.(df_cir.l_cap_3)
        df_cir.t_tap = Float64.(df_cir.t_tap)
        df_cir.t_shift = Float64.(df_cir.t_shift)
        df_cir.l_status = Int64.(df_cir.l_status)
        df_cir.ang_min = Float64.(df_cir.ang_min)
        df_cir.ang_max = Float64.(df_cir.ang_max)

        return df_cir
    end

    cd(folder_path) # Load the folder were the input data files are stored

    DBUS     = read_bus_data()          # Generate the Struct with Buses data
    DGEN     = read_gen_data()          # Generate the Struct with Generators data
    DCIR     = read_circuit_data()      # Generate the Struct with Circuits data

    # For the code to work properly, the bus indices must be set in ascending order from 1 to nBUS
    bus_mapping, reverse_bus_mapping = Mapping_Buses_Labels(DBUS) # Map the buses labels from old to new nomeclature
    DBUS.bus = [bus_mapping[b] for b in DBUS.bus]                              # Rename the buses labels from 1 to nBUS

    # Map the buses labels to be in ascending order from 1 to nBUS
    DGEN.bus      = [bus_mapping[b] for b in DGEN.bus]
    DCIR.from_bus = [bus_mapping[b] for b in DCIR.from_bus]
    DCIR.to_bus   = [bus_mapping[b] for b in DCIR.to_bus]

    return DBUS, DGEN, DCIR, bus_mapping, reverse_bus_mapping # Return the data
end

# Function used to map the from old to new nomeclature
function Mapping_Buses_Labels(DBUS::DataFrame)

    # Given bus numbers
    original_buses = DBUS.bus

    # Create a dictionary that maps original bus labels to new indices
    bus_mapping = OrderedDict(original_buses[i] => i for i in eachindex(original_buses))

    # Reverse mapping (for converting back later)
    reverse_bus_mapping = OrderedDict(i => original_buses[i] for i in eachindex(original_buses))

    return bus_mapping, reverse_bus_mapping
end

# Function that can change the buses labels according to the new nomenclature
function Change_Buses_Labels(DBUS::DataFrame, DGEN::DataFrame, DCIR::DataFrame, bus_mapping::OrderedDict)
    
    # Convert using the reverse mapping
    DBUS.bus      = [bus_mapping[b] for b in DBUS.bus]
    DGEN.bus      = [bus_mapping[b] for b in DGEN.bus]
    DCIR.from_bus = [bus_mapping[b] for b in DCIR.from_bus]
    DCIR.to_bus   = [bus_mapping[b] for b in DCIR.to_bus]

    return DBUS, DGEN, DCIR
end

# Function that can return the buses labels according to the original nomenclature
function Reverse_Buses_Labels(DBUS::DataFrame, DGEN::DataFrame, DCIR::DataFrame, reverse_bus_mapping::OrderedDict)
        
    # Convert using the reverse mapping
    DBUS.bus      = [reverse_bus_mapping[b] for b in DBUS.bus]
    DGEN.bus      = [reverse_bus_mapping[b] for b in DGEN.bus]
    DCIR.from_bus = [reverse_bus_mapping[b] for b in DCIR.from_bus]
    DCIR.to_bus   = [reverse_bus_mapping[b] for b in DCIR.to_bus]

    return DBUS, DGEN, DCIR
end
