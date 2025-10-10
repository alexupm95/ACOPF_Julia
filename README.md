# ACOPF_Julia
This code solves the AC Optimal Power Flow.

To run the code and change the input parameters, use the file "main.jl"

The code stores Input Data in DataFrames. Some of the Output Data is also stored in DataFrames.

To install the required Julia packages, run:

```julia
using Pkg

Pkg.add("LinearAlgebra")
Pkg.add("SparseArrays")
Pkg.add("DataFrames")
Pkg.add("Printf")
Pkg.add("CSV")
Pkg.add("DataStructures")
Pkg.add("JuMP")
Pkg.add("Ipopt")
Pkg.add("AmplNLWriter")
Pkg.add("Couenne_jll")
