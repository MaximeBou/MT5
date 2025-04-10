<chart>
id=133876642446648718
symbol=EURUSD
description=Euro vs US Dollar
period_type=0
period_size=15
digits=5
tick_size=0.000000
position_time=1744187400
scale_fix=0
scale_fixed_min=1.090900
scale_fixed_max=1.119600
scale_fix11=0
scale_bar=0
scale_bar_val=1.000000
scale=8
mode=1
fore=0
grid=0
volume=0
scroll=1
shift=1
shift_size=19.762259
fixed_pos=0.000000
ticker=1
ohlc=0
one_click=0
one_click_btn=0
bidline=1
askline=1
lastline=0
days=1
descriptions=0
tradelines=1
tradehistory=1
window_left=156
window_top=156
window_right=1349
window_bottom=574
window_type=3
floating=0
floating_left=0
floating_top=0
floating_right=0
floating_bottom=0
floating_type=1
floating_toolbar=1
floating_tbstate=
background_color=15794175
foreground_color=7346457
barup_color=65407
bardown_color=8894686
bullcandle_color=65280
bearcandle_color=255
chartline_color=65280
volumes_color=17919
grid_color=10061943
bidline_color=65280
askline_color=255
lastline_color=49152
stops_color=16711935
windows_total=2

<window>
height=121.393035
objects=3

<indicator>
name=Main
path=
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1
</indicator>

<indicator>
name=Moving Average
path=
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1

<graph>
name=
draw=129
style=0
width=2
arrow=251
color=65280
</graph>
period=12
method=0
</indicator>

<indicator>
name=Moving Average
path=
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1

<graph>
name=
draw=129
style=0
width=2
arrow=251
color=16711935
</graph>
period=25
method=0
</indicator>

<indicator>
name=Moving Average
path=
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1

<graph>
name=
draw=129
style=0
width=2
arrow=251
color=255
</graph>
period=50
method=0
</indicator>
<object>
type=32
name=autotrade #52304090820 sell 10.03 EURUSD at 1.09106, EURUSD
hidden=1
color=1918177
selectable=0
date1=1744132944
value1=1.091060
</object>

<object>
type=31
name=autotrade #52304312496 buy 10.03 EURUSD at 1.09156, SL, profit 
hidden=1
descr=[sl 1.09156]
color=11296515
selectable=0
date1=1744134952
value1=1.091560
</object>

<object>
type=2
name=autotrade #52304090820 -> #52304312496, SL, profit -501.50, EUR
hidden=1
descr=1.09106 -> 1.09156
color=1918177
style=2
selectable=0
ray1=0
ray2=0
date1=1744132944
date2=1744134952
value1=1.091060
value2=1.091560
</object>

</window>

<window>
height=28.606965
objects=0

<indicator>
name=Custom Indicator
path=Indicators\Market\MACD Trading View Style.ex5
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=4
fixed_height=-1

<graph>
name=MACD
draw=1
style=0
width=1
color=16711680
</graph>

<graph>
name=Signal
draw=1
style=0
width=1
color=255
</graph>

<graph>
name=Histogram
draw=11
style=0
width=4
color=10135078,14409650,13815295,5395199
</graph>
<inputs>
InpFastEMA=12
InpSlowEMA=26
InpSignalSMA=9
InpAppliedPrice=1
InpOscillatorMAType=1
InpSignalMAType=1
InpDarkTheme=false
</inputs>
</indicator>
</window>
</chart>