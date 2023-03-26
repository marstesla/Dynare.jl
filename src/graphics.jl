using KernelDensity
using Plots

function graph_display(g)
    if get(ENV, "TERM_PROGRAM", "") == "vscode"
        display(g)
    end
end

function plot(
    variables::Vector{Vector{Float64}};
    bar_variable::Vector{Float64} = Vector{Float64}([]),
    first_period::Int64 = 1,
    plot_title::String = "Smoothed value",
    plot_legend::Tuple = (),
    plot_filename::String = "",
    plot_legend_position::Symbol = :topright,
)
    local myplot
    # deal first with bar variable
    if length(bar_variable) > 0
        variables = pushfirst!(variables, bar_variable)
    end
    for (i, v) in enumerate(variables)
        if length(plot_legend) > 0
            thislabel = plot_legend[i]
        else
            thislabel = ""
            plot_legend_position = false
        end
        if i == 1
            if length(bar_variable) > 0
                len = length(bar_variable)
                xb = collect(range(first_period, length = len))
                myplot = Plots.bar(
                    xb,
                    bar_variable,
                    label = thislabel,
                    legend = plot_legend_position,
                    title = plot_title,
                )
                twinx()
            else
                x = collect(range(first_period, length = length(v)))
                myplot = Plots.plot(
                    x,
                    v,
                    label = thislabel,
                    legend = plot_legend_position,
                    title = plot_title,
                    linewidth = 3,
                )
            end
        else
            x = collect(range(first_period, length = length(v)))
            myplot = Plots.plot!(x, v, label = thislabel, linewidth = 3)
        end
    end
    graph_display(myplot)
    if length(plot_filename) > 0
        Plots.savefig(plot_filename)
    end
end

function plot(
    variable::Vector{Float64};
    bar_variable::Vector{Float64} = Vector{Float64}([]),
    first_period::Int64 = 1,
    plot_title::String = "Smoothed value",
    plot_legend::Tuple = (),
    plot_filename::String = "",
    plot_legend_position::Symbol = :topright,
)
    local myplot
    # deal first with bar variable
    if length(plot_legend) > 0
        thislabel = plot_legend
    else
        thislabel = ""
        plot_legend_position = false
    end
    if length(bar_variable) > 0
        len = length(bar_variable)
        xb = collect(range(first_period, length = len))
        myplot = Plots.bar(
            xb,
            bar_variable,
            label = thislabel[1],
            legend = plot_legend_position,
            title = plot_title,
        )
        x = collect(range(first_period, length = length(variable)))
        lims = Plots.ignorenan_extrema(myplot[1].attr[:yaxis])
        m, M = extrema(variable)
        tb = (lims[2] - lims[1]) / (M - m)
        variable = tb * (variable .- m) .+ lims[1]
        Plots.plot!(x, variable, label = thislabel[2], title = plot_title, linewidth = 3)
        myplot = twinx()
        myplot = Plots.plot!(myplot, ylims = (m, M))
    else
        x = collect(range(first_period, length = length(variable)))
        myplot = Plots.plot(
            x,
            variable,
            label = thislabel[1],
            legend = plot_legend_position,
            title = plot_title,
            linewidth = 3,
        )
    end
    graph_display(myplot)
    if length(plot_filename) > 0
        Plots.savefig(plot_filename)
    end
end

function plot_irfs(irfs, model, symboltable, filepath)
    x = axes(first(irfs)[2])[1]
    endogenous_names = get_endogenous_longname(symboltable)
    exogenous_names = get_exogenous_longname(symboltable)
    for i = 1:model.exogenous_nbr
        exogenous_name = exogenous_names[i]
        (nbplt, nr, nc, lr, lc, nstar) = pltorg(model.original_endogenous_nbr)
        ivars = 1:nr*nc
        for p = 1:nbplt-1
            filename = "$(filepath)_$(exogenous_name)_$(p).png"
            plot_panel(
                x,
                Matrix(irfs[Symbol(exogenous_name)][:,ivars]),
                "Orthogonal shock to $(exogenous_name)",
                endogenous_names[ivars],
                nr,
                nc,
                nr * nc,
                filename,
            )
            ivars += nr * nc
        end
        ivars = ivars[1:nstar]
        filename = "$(filepath)_$(exogenous_name)_$(nbplt).png"
        plot_panel(
            x,
            Matrix(irfs[Symbol(exogenous_name)][:, ivars]),
            "Orthogonal shock to $(exogenous_name)",
            endogenous_names[ivars],
            lr,
            lc,
            nstar,
            filename,
        )
    end
end

function plot_priors(;context::Context=context)
    @assert length(ep.prior) > 0 "There is no defined priors"
    ep = context.work.estimated_parameters
    path = "$(context.modfileinfo.modfilepath)/graphs/"
    mkpath(path)
    filepath = "$(path)/Priors"
    nprior = length(ep.prior)
    X = zeros(100, nprior)
    Y = zeros(100, nprior)
    for (i, p) in enumerate(ep.prior)
        X[:, i] = range(StatsPlots.yz_args(p)..., 100)
        for j in axes(X, 1)
            Y[j, i] = pdf(p, X[j, i])
        end 
    end     
    (nbplt, nr, nc, lr, lc, nstar) = pltorg(nprior)
    ivars = collect(1:nr*nc)
    for p = 1:nbplt-1
        filename = "$(filepath)_$(p).png"
        plot_panel(
            X[:, ivars],
            Y[:, ivars],
            "Priors",
            ep.name[ivars],
            nr,
            nc,
            nr * nc,
            filename,
        )
        ivars .+= nr * nc
    end
    ivars = ivars[1:nstar]
    filename = "$(filepath)_$(nbplt).png"
    plot_panel(
        X[:, ivars],
        Y[:, ivars],
        "Priors",
        ep.name[ivars],
        lr,
        lc,
        nstar,
        filename,
    )
end

function plot_panel(
    x,
    y,
    title,
    ylabels,
    nr,
    nc,
    nstar,
    filename,
)
    sp = [Plots.plot(showaxis = false, ticks = false, grid = false) for i = 1:nr*nc]
    for i = 1:nstar
        if ndims(x) == 1
            xx = x
        else
            xx = x[:, i]
        end 
        yy = y[:, i]
        title1 = (i == 1) ? title : ""
        if all(yy .> 0)
            lims = (0, Inf)
        elseif all(yy .< 0)
            lims = (-Inf, 0)
        else
            lims = (-Inf, Inf)
        end
        sp[i] =
            Plots.plot(xx, yy, title = title1, ylims = lims, label = ylabels[i], kwargs...)
    end

    pl = Plots.plot(sp..., layout = (nr, nc), size = (900, 900))
    graph_display(pl)
    savefig(filename)
end

function pltorg(number)
    nrstar = 3
    ncstar = 3
    nstar = nrstar * ncstar
    nbplt = 0
    nr = 0
    nc = 0
    lr = 0
    lc = 0
    nbplt = ceil(number / nstar)
    (d, r) = divrem(number, nstar)
    if r == 0
        return (d, nrstar, ncstar, nrstar, ncstar, nstar)
    else
        (lr, lc) = pltorg_0(r)
        return (d + 1, nrstar, ncstar, lr, lc, r)
    end
end

function pltorg_0(number)
    @assert number < 10
    if number == 1
        lr = 1
        lc = 1
    elseif number == 2
        lr = 2
        lc = 1
    elseif number == 3
        lr = 3
        lc = 1
    elseif number == 4
        lr = 2
        lc = 2
    elseif number < 7
        lr = 3
        lc = 2
    elseif number < 10
        lr = 3
        lc = 3
    end
    return (lr, lc)
end

function plot_prior_posterior(;context::Context=context)
    ep = context.work.estimated_parameters
    chains = context.results.model_results[1].estimation.posterior_mcmc_chains
    mode = context.results.model_results[1].estimation.posterior_mode
    @assert length(ep.prior) > 0 "There is no defined prior"
    @assert length(chains) > 0 "There is no MCMC chain"
    path = "$(context.modfileinfo.modfilepath)/graphs/"
    mkpath(path)
    filename = "$(path)/PriorPosterior"
    nprior = length(ep.prior)
    (nbplt, nr, nc, lr, lc, nstar) = pltorg(nprior)
    ivars = collect(1:nr*nc)
    for p = 1:nbplt-1
        filename = "$(filename)_$(p).png"
        plot_panel_prior_posterior(
            ep.prior,
            chains,
            mode,
            "Priors",
            ep.name,
            ivars,
            nr,
            nc,
            nr * nc,
            filename
        )
        ivars .+= nr * nc
    end
    ivars = ivars[1:nstar]
    filename = "$(filename)_$(nbplt).png"
    plot_panel_prior_posterior(
        ep.prior,
        chains,
        mode,
        "Priors",
        ep.name,
        ivars,
        lr,
        lc,
        nstar,
        filename
    )
end

function plot_panel_prior_posterior(
    prior,
    chains,
    mode,
    title,
    ylabels,
    ivars,
    nr,
    nc,
    nstar,
    filename;
    kwargs...
)
    sp = [Plots.plot(showaxis = false, ticks = false, grid = false) for i = 1:nr*nc]
    for (i, j) in enumerate(ivars)
        posterior_density = kde(vec(get(chains, Symbol(ylabels[j]))[1].data))
        title1 = (j == 1) ? title : ""
        
        sp[i] = Plots.plot(prior[j], title = ylabels[j], labels = "Prior", kwargs...)
        plot!(posterior_density, labels = "Posterior")
    end

    pl = Plots.plot(sp..., layout = (nr, nc), size = (900, 900), plot_title = "Prior and posterior distributions")
    graph_display(pl)
    savefig(filename)
end

function plot_priorprediction_irfs(irfs, model, symboltable, filepath)
    x = axes(first(first(irfs))[2])[1]
    endogenous_names = get_endogenous_longname(symboltable)
    exogenous_names = get_exogenous_longname(symboltable)
    for i = 1:model.exogenous_nbr
        exogenous_name = exogenous_names[i]
        (nbplt, nr, nc, lr, lc, nstar) = pltorg(model.original_endogenous_nbr)
        ivars = 1:nr*nc
        irfs1 = [ir[Symbol(exogenous_name)] for ir in irfs]
        for p = 1:nbplt-1
            filename = "$(filepath)_$(exogenous_name)_$(p).png"
            plot_panel_priorprediction_irfs(
                x,
                irfs,
                exogenous_name,
                "Orthogonal shock to $(exogenous_name)",
                endogenous_names,
                ivars,
                nr,
                nc,
                nr * nc,
                filename,
            )
            ivars += nr * nc
        end
        ivars = ivars[1:nstar]
        filename = "$(filepath)_$(exogenous_name)_$(nbplt).png"
        plot_panel_priorprediction_irfs(
            x,
            irfs,
            exogenous_name,
            "Orthogonal shock to $(exogenous_name)",
            endogenous_names,
            ivars,
            lr,
            lc,
            nstar,
            filename,
        )
    end
end

function plot_panel_priorprediction_irfs(
    x,
    irfs,
    exogenous_name,
    title,
    endogenous_names,
    ivars,
    nr,
    nc,
    nstar,
    filename
)
    sp = [Plots.plot(showaxis = false, ticks = false, grid = false) for i = 1:nstar]
    for (i, j) in enumerate(ivars)
        M = zeros(40, length(irfs))
        for (k, ir) in enumerate(irfs)
            m = Matrix(ir[Symbol(exogenous_name)][:, Symbol(endogenous_names[j])])
            @views M[:, k] .= m
        end
        Q = zeros(40, 5)
        for k in 1:40
            @views Q[k, :] .= quantile(M[k,:], [0.1, 0.3, 0.5, 0.7, 0.9])
        end
        title1 = (j == 1) ? title : ""
        colors = palette(:Blues_3)
        Q1 = view(Q,:, 1)
        Q2 = view(Q,:, 2)
        Q3 = view(Q,:, 3)
        Q4 = view(Q,:, 4)
        Q5 = view(Q,:, 5)
        sp[i] = Plots.plot(x, Q3, ribbon = (Q5-Q3, Q3-Q1), color = colors[2],Qtitle = endogenous_names[j], labels = false)
        plot!(sp[i], x, Q3, ribbon = (Q4-Q3, Q3-Q2), color = colors[3])
        display(sp[i])
    end

    pl = Plots.plot(sp..., layout = (nr, nc), size = (900, 900), plot_title = "Priorprediction: Orthogonal shock to $(exogenous_name)")
    graph_display(pl)
    savefig(filename)
end

function plot(aat::AxisArrayTable; label = (), title = "", filename = "")
    pl = Plots.plot(aat, label = label, title = title)
    graph_display(pl)
    savefig(filename)
end
