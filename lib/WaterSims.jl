module WaterSims

using CSV 
using DataFrames
using Formatting
using StatsBase 
using TableTransforms
using Formatting

using ScottishTaxBenefitModel
using .BCCalcs
using .Definitions
using .ExampleHelpers
using .FRSHouseholdGetter
using .ExampleHouseholdGetter
using .GeneralTaxComponents
using .ModelHousehold
using .Monitor
using .Runner
using .RunSettings
using .SimplePovertyCounts: GroupPoverty
using .SingleHouseholdCalculations
using .STBIncomes
using .STBOutput
using .STBParameters
using .TheEqualiser
using .Utils

export run, make_default_settings

export WEEKS_PER_YEAR

const FRS_DIR="/mnt/data/frs/"

function make_default_settings() :: Settings
    # settings = Settings()
    settings = RunSettings.get_all_uk_settings_2023()
    settings.do_marginal_rates = false
    settings.requested_threads = 4
    settings.means_tested_routing = uc_full
    settings.do_health_esimates = true
    # settings.ineq_income_measure = bhc_net_income # FIXME TEMP
    return settings
end

function tabulate( d :: DataFrame, col :: Symbol )
    gavch = combine( groupby( d, [col]),
            (:weighted_water_change=>sum), # 
            (:weighted_people=>sum), # hh weight * people count
            (:weight=>sum))  
    println(typeof( gavch ))
    gavch.average_change = gavch.weighted_water_change_sum ./ gavch.weight_sum
    println(names(gavch))
    return gavch
end

function xts( a :: AbstractArray ) :: Tuple
    n = size(a)[1]
    return ((1:n),Utils.pretty.(string.(a)))
end

#=
function plot_h( decile :: DataFrame, tenure :: DataFrame, dwelling :: DataFrame, region::DataFrame ) :: Figure
    f = Figure( )
    Makie.theme(:fonts)
    ax1 = Axis(f[1,1], title="Water Bills as %...", xlabel="Decile", ylabel="£s pw")
    ax2 = Axis(f[2,1], title="Water Bills as %...", xlabel="Tenure", ylabel="£s pw", xticks=xts(tenure.tenure), xticklabelrotation=1)
    ax3 = Axis(f[1,2], title="Water Bills as %...", xlabel="Dwelling Type", ylabel="£s pw", xticks=xts(dwelling.dwelling), xticklabelrotation=1)
    ax4 = Axis(f[2,2], title="Water Bills as %...", xlabel="Region", ylabel="£s pw", xticks=xts(region.region), xticklabelrotation=1)
    linkyaxes!(ax1, ax2 )
    barplot!(ax1,decile.decile,decile.avchange )
    barplot!(ax2,tenure.avchange)
    barplot!(ax3,dwelling.avchange)
    barplot!(ax4,region.avchange)
    f
end

function plot_v( decile :: DataFrame, tenure :: DataFrame, dwelling :: DataFrame, region::DataFrame, n :: Number = 1 ) :: Figure
    pts = Int(trunc(12*n))
    f = Figure(; size=(n*1024,n*1024)) # ; fontsize=8, fonts = (; regular = "Gill Sans", weird = "Blackchancery" ))
    ax1 = Axis(f[1,1]; title="Decile", xlabel="£s pw" )
    ax2 = Axis(f[2,1]; title="Tenure", xlabel="£s pw", yticks=xts(tenure.tenure)) #, xlabelfont=:regular, ylabelfont=:regular)
    ax3 = Axis(f[1,2]; title="Dwelling Type", xlabel="£s pw", yticks=xts(dwelling.dwelling)) #, xlabelfont=:regular, ylabelfont=:regular)
    ax4 = Axis(f[2,2]; title="Region", xlabel="£s pw", yticks=xts(region.region)) #, xlabelfont=:regular, ylabelfont=:regular)
    linkxaxes!(ax1, ax2, ax3, ax4 )
    barplot!(ax1,decile.decile,decile.avchange; direction=:x )
    barplot!(ax2,tenure.avchange; direction=:x)
    barplot!(ax3,dwelling.avchange; direction=:x)
    barplot!(ax4,region.avchange; direction=:x)
    update_theme!(fontsize=pts)
    update_theme!(fonts=(; regular="Gill Sans"))
    f
end
=#

export run, initialise

function run( settings :: Settings, target1::Real )::DataFrame
    tot_wat = 0.0
    out = DataFrame( 
        weight = zeros( settings.num_households),
        decile = zeros( Int, settings.num_households ),
        weighted_people = zeros( settings.num_households),
        weighted_households = zeros( settings.num_households),
        weighted_water_1 = zeros( settings.num_households),
        weighted_water_2 = zeros( settings.num_households),
        dwelling = Array{DwellingType}(undef, settings.num_households ),
        tenure = Array{Tenure_Type}(undef, settings.num_households ),
        region = Array{Standard_Region}(undef, settings.num_households ),
        children = fill(false,  settings.num_households ),
        pensioner = fill(false,  settings.num_households ),
        otherhh = fill(false,  settings.num_households ),
        people = zeros( Int, settings.num_households ),
        water1 = zeros( settings.num_households),
        water2 = zeros( settings.num_households))
    @time for hno in 1:settings.num_households
        hh = FRSHouseholdGetter.get_household(hno)
        if ! (hh.region in (Scotland,Wales,Northern_Ireland))
                println( hh.water_and_sewerage )
            tot_wat += (hh.water_and_sewerage*hh.weight)
            out[hno,:weight] = hh.weight
            out[hno,:tenure] = hh.tenure
            out[hno,:region] = hh.region
            out[hno,:dwelling] = hh.dwelling
            out[hno,:children] = has_children( hh )
            out[hno,:water1] = hh.water_and_sewerage
            out[hno,:water2] = out[hno,:water1]*target1
            out[hno,:weighted_households] = hh.weight
            out[hno,:decile] = hh.original_income_decile
            out[hno,:people] = num_people(hh)
        end
    end # hhld loop
    out.weighted_people = out.weight .* out.people
    out.weighted_water_1 = out.water1.*out.weight
    out.weighted_water_2 = out.water2.*out.weight
    out.weighted_water_change = out.weighted_water_2 - out.weighted_water_1
    tot_wat*=(WEEKS_PER_YEAR/1_000_000)
    println( format( tot_wat, commas=true, precision=0))
    w2 = out.weight'out.water1*WEEKS_PER_YEAR/1_000_000
    println( w2 )
    @assert tot_wat ≈ w2
    println( )
    out[out.weight .> 0,:]
end
  

# Write your package code here.
# do & save a startup run
function initialise(; reset = true )::Settings
    settings = make_default_settings()  
    @info "initial startup"
    settings.num_households, settings.num_people, nhh2 = 
        FRSHouseholdGetter.initialise( settings; reset=reset ) # force UK dataset 
    ExampleHouseholdGetter.initialise( settings ) # force a reload for reasons I don't quite understand.
    return settings
end

end
