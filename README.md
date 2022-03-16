# Visual-SIRD-Simulator
A visual simulator of infection spreading

Based on the SIRD (Susceptibles, Infectious, Removed (immunes), Dead) model. it also simulates the mutability of the infection, based on a customizable probability variable. the charts at the end of most simulations represent the stats of each variation of the original infection, so that we can have a map of what kind of infection infected the simulation's population.
for reference, these are the names used in the chart:
TA = infection rate
RI = infection radius
TM = mortality rate
TI = immunization time (time that passes until an infected person becomes immune or dead)
the charts have a slightly different color depending on the stats of that mutation.

In the simulation, green dots are susceptible people, red ones are infectious, blue ones are immunes, and white crosses are deads.

to run, open or compile `GSIR.opal` using the opal compiler.
