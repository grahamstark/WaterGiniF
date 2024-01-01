module App

using GenieFramework
using Main.Maths
using Main.WaterSims
using PlotlyBase
using Formatting
using DataFrames

@genietools

settings = WaterSims.initialise(reset=true) # WaterSims.make_default_settings()

function make_base_run(target)
    out = WaterSims.run( settings, target )
    println( "settings=$(settings)")
    println( out[1:10,:])
    deciles = WaterSims.tabulate( out, :decile )
    deciles.average_change_pw = Formatting.format.(deciles.average_change, precision=2)
    println( names(deciles))
    tenures = WaterSims.tabulate( out, :tenure )
    tenures.average_change_pw = Formatting.format.(tenures.average_change, precision=2)

    regions = WaterSims.tabulate( out, :region )
    regions.average_change_pw = Formatting.format.(regions.average_change, precision=2)
    children = WaterSims.tabulate( out, :children )
    children.average_change_pw = Formatting.format.(children.average_change, precision=2)
    decbar = [
        bar( 
            x=deciles.decile, 
            y=deciles.average_change )]
    base_revenues = WEEKS_PER_YEAR*sum( out.weighted_water_1 )
    println("make base run exiting")
    (; deciles, tenures, regions, base_revenues, children, decbar )
end

const BASE_RUN = make_base_run(1.0)

function getbase(which::Symbol)
    BASE_RUN[which]
end

@app begin

    @in target = 0.0
    
    @out decbar = getbase( :decbar )
    # FIXME all this tables malarkey isn't needed. See:
    # https://genieframework.com/docs/stippleui/v0.20/API/tables.html
    @out deciles = DataTable(getbase(:deciles)[:,[:decile,:average_change_pw]])
    @out tenures = DataTable(getbase(:tenures))[:,[:tenure,:average_change_pw]]
    @out regions = DataTable(getbase(:regions))[:,[:region,:average_change_pw]]
    @out children = DataTable(getbase(:children))[:,[:children,:average_change_pw]]
    @out data_pagination::DataTablePagination = DataTablePagination(rows_per_page=50)
    @out billchange = 0.0
    @out targetmn = "0"
    @out plotlayout = PlotlyBase.Layout(
        title="Change in Water and Sewerage Bills From Poorest To Richest",
        yaxis=attr(
            title="Extra Water Bill in £s pw",
            showgrid=true,
            range=[0, 20]
        ),
        xaxis=attr(
            title="Household Income Decile",
            showgrid=true
        ),

    )

    @onchange target begin
        br = getbase(:base_revenues)
        billchange = 100.0*target/br
        out = make_base_run( 1+(billchange/100.0) )
        deciles = DataTable( out.deciles )[:,[:decile,:average_change_pw]]
        tenures = DataTable( out.tenures )[:,[:tenure,:average_change_pw]]
        children = DataTable( out.children )[:,[:children,:average_change_pw]]
        regions = DataTable( out.regions )[:,[:region,:average_change_pw]]
        decbar = out.decbar
        targetmn = Formatting.format( target/1_000_000, commas=true )
    end 

end

function ui()
    [
        row([
            cell([
                h1("Your Water Bill")
            ]),
        ]),
        row([
            cell([
                span("How much investment do you need? (per year):" )
                slider(0.0:50_000_000.0:20_000_000_000.0,:target)
                p("Target to be raised: <b>£{{targetmn}}mn</b> p.a. Average bill change <b>{{billchange.toFixed(1)}}%</b>")
            ]),
            cell([
                """ 
                <h2>Who owns our water?</h2>

The English water companies are more than 70% owned by shareholders abroad, for example:
<ul>
    <li>Wessex Water is 100% owned by a Malaysian company, YTL</li>
    <li>Northumbrian Water is owned by Hong Kong businessman Li Ka Shing</li>
    <li>Thames Water is partly owned by investors from the United Arab Emirates, Kuwait, China and Australia</li>
</ul>

Welsh Water is a not for profit. Scottish Water and Northern Irish Water are both in public ownership.

    <h3>Key facts</h3>

    Since privatisation, £72 billion has gone to shareholders - around £2 billion a year on average
    The water companies have built up a debt mountain of over £60 billion and used this to finance dividends for shareholders
    The average pay for a water company CEO is £1.7 million a year. The biggest earner is Steve Mogford, CEO of United Utilities, on £2.9 million
    Our bills have gone up by 40% in real terms since privatisation
    Water companies are leaking away 2.4 billion litres of water a day (up to a quarter of their supply)
    The Environment Agency has said that by 2050 some rivers will see 50-80% less water during the summer months – so water is a precious resource we need to conserve
    Every day, the water companies discharge raw sewage into our rivers and seas more than 1000 times on average - over 9 million hours since 2016
    
    Only 14 percent of English rivers are considered to have good ecological status
    In Scotland, water is in public ownership. Bills are lower and rivers and seas are cleaner
    Publicly owned Scottish Water has spent £72 more per household per year (35% more) than the English water companies. If England had invested at this rate, an extra £28 billion would have gone into the infrastructure to tackle problems like leaks and sewage
    In France, a number of cities have brought water back into public ownership. They didn’t sell off the assets like England did which means they can just wait until contracts come to an end
    In Paris water came back into public ownership in 2011. The publicly owned company L’Eau de Paris has built still and sparkling water fountains throughout the city!
    69% of the British public want water back in public hands
    70% of Red Wall voters want water in public ownership

        """
            ])
        ]),
        row([
            cell([
                plot(:decbar; layout=:plotlayout )
            ]),
            cell([
                p("")
            ])
        ]),

        row([
            cell([
                GenieFramework.table(:deciles; title="By Decile", pagination=:data_pagination)
            ])
            cell([
                GenieFramework.table(:tenures; title="By Tenure", pagination=:data_pagination)
            ])
            cell([
                GenieFramework.table(:regions; title="By Region", pagination=:data_pagination)
            ])
            cell([
                GenieFramework.table(:children; title="By Children", pagination=:data_pagination)
            ])
        ])
    ]
end


@page( "/", ui )

end # module