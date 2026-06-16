@doc raw"""
    dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)
The addtional constraints imposed upon the line flows in the case of DC-OPF are as follows:
For the definition of the line flows, in terms of the voltage phase angles:
```math
\begin{aligned}
        & \Phi_{l,t}=\mathcal{B}_{l} \times (\sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})}) \quad \forall l \in \mathcal{L}, \; \forall t  \in \mathcal{T}\\
\end{aligned}
```
For imposing the constraint of maximum allowed voltage phase angle difference across lines:
```math
\begin{aligned}
    & \sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})} \leq \Delta \theta^{\max}_{l} \quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
	& \sum_{z\in \mathcal{Z}}{(\varphi^{map}_{l,z} \times \theta_{z,t})} \geq -\Delta \theta^{\max}_{l} \quad \forall l \in \mathcal{L}, \forall t  \in \mathcal{T}\\
\end{aligned}
```
Finally, we enforce the reference voltage phase angle constraint (for the slack bus/reference bus):
```math
\begin{aligned}
\theta_{1,t} = 0 \quad \forall t  \in \mathcal{T}
\end{aligned}
```

"""
function dcopf_transmission!(EP::Model, inputs::Dict, setup::Dict)
    println("DC-OPF Module")

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    L = inputs["L"]     # Number of transmission lines

    
    I, J, V = findnz(inputs["pNet_Map"])  # I=row index, J=col index, V=value
    nz_by_row = [Vector{Tuple{Int, Float64}}() for _ in 1:L]
    nz_by_col = [Vector{Tuple{Int, Float64}}() for _ in 1:Z]

    for k in eachindex(V)
        push!(nz_by_row[I[k]], (J[k], V[k]))
        push!(nz_by_col[J[k]], (I[k], V[k]))
    end

    ### DC-OPF variables ###

    # Voltage angle variables of each zone "z" at hour "t" 
    @variable(EP, vANGLE[z = 1:Z, t = 1:T])

    ### DC-OPF constraints ###

    # Power flow constraint:: vFLOW = DC_OPF_coeff * (vANGLE[START_ZONE] - vANGLE[END_ZONE])
    @constraint(EP,
            cPOWER_FLOW_OPF[l = 1:L, t = 1:T],
            EP[:vFLOW][l, t]==inputs["pDC_OPF_coeff"][l] *
                    sum(v * vANGLE[Int(z), t] for (z, v) in nz_by_row[l]))

    # Bus angle limits (except slack bus)
    @constraints(EP,
            begin
                cANGLE_ub[l = 1:L, t = 1:T],
                sum(v * vANGLE[Int(z), t] for (z, v) in nz_by_row[l]) <=
                inputs["Line_Angle_Limit"][l]
                cANGLE_lb[l = 1:L, t = 1:T],
                sum(v * vANGLE[Int(z), t] for (z, v) in nz_by_row[l]) >=
                -inputs["Line_Angle_Limit"][l]
            end)

    # Slack Bus angle limit
    @constraint(EP, cANGLE_SLACK[t = 1:T], vANGLE[1, t]==0)
end
