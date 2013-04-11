breed [ cells cell ] ;Hexagonal cells
breed [ units unit ] ;represents an infantry unit
breed [ armies army ] ;represents an army, made up of units
breed [ artilleries artillery ] ;represents an artillery brigade
breed [ dead-units dead-unit ] ;represents a captured unit
breed [ pathnodes pathnode ]

undirected-link-breed [rail-links rail-link]
globals [german-losses russian-losses waypoints tick-length tick-distance max-troops]  ;<(^_^)>  ]

;Define instance variables of the different turtles
cells-own [
  hex-neighbors  ;; agentset of 6 neighboring cells
  n              ;; used to store a count of white neighbors
  terrain        ;; {0=forest, 1=water, 2=desert, 3=mud, 4=swamp}
  hasrail
]

units-own [
  team                ;; Which Faction this unit is a part of
  group               ;; Different groups willl exhibit different behaviors or follow different orders
  troops              ;; Actual troop count
  maxTroops           ;; Starting troop count
  aimedWeapons        ;; Strength of the weapons that are aimed for direct fire (small arms)
  target              ;; [x y]
  neighb-enemies      ;; agent list of enemy units in neighboring hexes
  travelTime       ;; When a Russian 1st unit is north of the map, this is the number of miles they have left to travel
  nextCell            ;; used for BFS
  isEngaged           ;; is currently attacking (is adjacent to an enemy)
]

dead-units-own [
  team
  troops
]

rail-links-own []
artilleries-own []

pathnodes-own [
  hex
  previousNode  ;; Previous node in the path 
  visited
]

;; Set up the simulation
to setup
  clear-all
  setup-grid
  setup-waypoints
  add-terrain
  ;tick-length in hours
  set tick-length 3
  ;Max troops deployed in a single square km is roughly 400, so max troops per 25 square km (one hex) is 10000
  set max-troops 10000
  ;add-rail
  add-units
  set german-losses 0
  set russian-losses 0
  reset-ticks
end

to setup-waypoints
  ;; 
  ;;
  
end

;;Set up the grid
to setup-grid
  set-patch-size mapSize
  set-default-shape cells "hex"
  set-default-shape units "unit"
  set-default-shape dead-units "x"
  
  ask patches
    [ sprout-cells 1
      [ set size 1.4
        set color green - 3  ;; dark gray
                             ;; shift even columns down
        if pxcor mod 2 = 0
          [ set ycor ycor - 0.5 ] ] ]
  ;; set up the hex-neighbors agentsets
  ask cells
    [ ifelse pxcor mod 2 = 0
      [ set hex-neighbors cells-on patches at-points [[0 1] [1 0] [1 -1] [0 -1] [-1 -1] [-1 0]] ]
      [ set hex-neighbors cells-on patches at-points [[0 1] [1 1] [1  0] [0 -1] [-1  0] [-1 1]] ] ]
end

;; Resize the world and set the hexagon tiles' colors based on input terrain type
to add-terrain
  let data []
  file-open "tannenhexmap.txt"
  while [ not file-at-end? ] [
    set data lput file-read data ]
  file-close 
  
  resize-world 0 (length ((item 0 data)) - 1) 0 ((length data) - 1)
  let def-color green + 3
  ; Set the colors of the hexes
  ask patches
    [ ask cells-here
      ; This is basing the coordinates of the array off the size of the physical world, which is dangerous
      [ set terrain item (xcor) (item (max-pycor - ycor) data) 
        if-else terrain = 0 [ color-terr def-color ] [ 
          if-else terrain = 1 [ color-terr blue + 2 ] [ ;water
            if-else terrain = 2 [ color-terr def-color ] [
              if-else terrain = 3 [color-terr def-color ] [
                if-else terrain = 4 [ color-terr  def-color ] [
                  color-terr green - 5 ] ] ] ] ] ] ]
end

;; Color a terrain hex a certain color
to color-terr [ col ] ask cells-here [ set color col ] end

;; Move a unit into position on the hex, and set its color
to display-unit [allegiance]
  ifelse allegiance = 0 [ set color black ] [ set color red ]
  if pxcor mod 2 = 0 [ set ycor ycor - 0.5 ]
end

to step
  move-armies
  ask units [ set size (troops / max-troops) + 0.2 ]
  tick
end

to go
  step
  ;check-victory-conditions-for-army-surrender
end

;use this function if you want victory conditions to be defined on an army-by-army basis
to check-victory-conditions-for-army-surrender
  let germanEighthArmyTroops (sum [troops] of units with [group = 0])
  let russianSecondArmyTroops (sum [troops] of units with [group = 2])
  if russianSecondArmyTroops <= 0 [set russianSecondArmyTroops 1]
  let southern-german-ratio germanEighthArmyTroops / russianSecondArmyTroops
  
  if-else southern-german-ratio > 3 [ ;southern german victory
    let powCount (sum [troops] of units with [group = 2])
    let powHandlers (round powCount / 10)
    ask units with [group = 2] [die]
    let totalGermanTroops sum [troops] of units with [group = 0]
    ask units with [group = 0] [
        let troopFrac troops / totalGermanTroops ;the percentage of troops in this unit out of all russian units
        ask self [set troops (round troops - (troopFrac * powHandlers))] ;scale pow handlers by the percentage of troops in this unit
  ]] 
  [ if southern-german-ratio < (1 / 3) [ ;southern german defeat
      let powCount (sum [troops] of units with [group = 0])
      let powHandlers (round powCount / 10)
      ask units with [group = 0] [die]
      let totalRussianTroops sum [troops] of units with [group = 2]
      ask units with [group = 2] [
        let troopFrac troops / totalRussianTroops ;the percentage of troops in this unit out of all russian units
        ask self [set troops (round troops - (troopFrac * powHandlers))] ;scale pow handlers by the percentage of troops in this unit
  ]]]
end

; Army Control procedures: Movement, Targetting ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to move-armies
  set-targets
  set-neighb-enemies
 ; approach-armies
  ask (units with [travelTime = 0]) [ approach self ]
  ask (units with [travelTime > 0]) [ travel self ]
end

to approach-armies
  foreach sort(units with [travelTime = 0]) [ 
    if (any? ([hex-neighbors] of (one-of cells-on ?)) with [count units-here = 0 and terrain != 1])
    [
      bfs (one-of cells-on ?) (one-of cells-on [target] of ?) (?)
    ]
    ask ? [approach self]
  ]
end

to set-neighb-enemies
  ask units [
    let teamNumber [team] of self
    set neighb-enemies report-adjacent-divisions with [team != teamNumber] ;(divisions with [team != teamNumber and distance myself <= 1.1])
  ]
end

to set-targets
  ask units [
    let teamNumber [team] of self
    let neighbor one-of cells-here 
    set target min-one-of (units with [team != teamNumber and travelTime = 0]) [distance myself]
  ]
end

;Combat procedures;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; An attacker attacks all adjacent defenders with a proportion of his firepower.
to agg-attack [attacker proportion]
  let attackDamage round ([troops] of attacker * proportion * ([aimedWeapons] of attacker))
  
  if-else [team] of attacker = 0 [ set russian-losses russian-losses + attackDamage ]
    [set german-losses (german-losses + attackDamage)]
    
  let defenders [neighb-enemies] of attacker ;agent-set of defending divisions
  let defTroops sum [troops] of defenders ;defTroops is the total number of defending (adjacent) troops
  if deftroops <= 1 [set defTroops 1]
  let victoryRatio ([troops] of attacker / defTroops) ;ensure no division by 0
  if (victoryRatio > 3) [ set troops (round troops - (0.1 * defTroops)) ] ;they will surrender
  
  ask defenders [
    let troopFrac (troops / defTroops) ;the percentage of troops in this unit out of all defending units
    let losses (troopFrac * attackDamage)
    ask self [set troops (round troops - losses)] ;scale attack damage by the percentage of troops in this division
    if-else (victoryRatio > 3)[ ask self [die] ] ;surrender point
    [
      if ([troops] of self < (0.45 * [maxTroops] of self) and [team] of self = 1) [
        ask patch [xcor] of self [ycor] of self [ sprout-dead-units 1 [
          set size 0.8
          set troops [troops] of self
          set team 1
          display-unit team
          set russian-losses (russian-losses + [troops] of self)
        ]]
        ask self [die]
      ]
    ]
  ]  
end

;; Approaches a units
;to approach
;  
;  if-else distance target <= 1 [ agg-attack self 1 ]
;    [
;      move-to nextCell
;    ]
;end

to approach [unit]
  ; TODO: Implement Breadth-First-Search to find shortest path to enemy
  ask division [
    let defenders [neighb-enemies] of self

    if (target != nobody) [
      ;if-else distance target <= 1 [ attack myself target 1 ]
      if-else (count defenders > 0) [ 
        set isEngaged true 
        agg-attack myself 1 ]
      [
        set isEngaged false
        face target
        let cell-here one-of cells-here
        forward 1
        let pclosest min-one-of (([hex-neighbors] of cell-here) with [(count units-here = 0 and count dead-units-here = 0) and terrain != 1]) [distance myself]
        if pclosest != nobody [
          move-to pclosest
        ]
      ]
    ]
  ]
end

;; Offscreen unit marching
to travel [unit]
  ask unit[ 
    set travelTime travelTime - tick-length
    if travelTime < 0[
      set travelTime 0
      show-turtle
    ]
  ]
end


; Run a breadth-first search for distance from the start to the goal
; Inputs are hexes that are not water
; goal is reachable by starting at start and moving between adjacent hexes that are not water
; Returns the next step to take
to bfs [start goal div]
  ;Start position is the head
  
  let currentNode nobody
  create-pathnodes 1 [
    set hex start
    set previousNode nobody
    set visited false
    hide-turtle
  ]
  set currentNode one-of pathNodes
  
  while [count pathnodes with [hex = goal] = 0]
  [
    
    ; "Enqueue" all the neighbors that have not already been added and that are not water
    foreach (sort ([hex-neighbors] of [hex] of currentNode) with [terrain != 1 and (count units-here = 0 or self = goal)])
    [
      if count pathnodes with [hex = ?] = 0
      [
        create-pathnodes 1 [
          set hex ?
          set previousNode currentNode
          set visited false
          hide-turtle
        ]
      ]
      
    ]
    
    ; "Dequeue" one hex
    let tempHex [hex] of currentNode
    ask currentNode [set visited true]
    set currentNode item 0 (sort pathNodes with [visited = false])
  ]
  
  
  ; Now that the goal has been found, find your way back to the beginning
  
  set currentNode one-of pathNodes with [hex = goal]
  
  while [[hex] of [previousNode] of currentNode != start] [ set currentNode [previousNode] of currentNode ]
  let returnval [hex] of currentNode
  ask pathNodes [die]
  
  ask div[set nextCell returnval]
  
end


; Add units
to add-units
  ;German 8th
  ; I Corps - starts near Seeben
  add-unit 4 8 8800 .06 0 0
  add-unit 5 8 8800 .06 0 0
  add-unit 5 7 8800 .06 0 0
  add-unit 5 9 8800 .06 0 0
  add-unit 6 10 8800 .06 0 0
  
  ; XVII Corps - starts near Heilsburg
  add-unit 22 24 8800 .06 0 0
  add-unit 23 23 8800 .06 0 0
  add-unit 22 23 8800 .06 0 0
  add-unit 23 24 8800 .06 0 0
  add-unit 21 24 8800 .06 0 0
  
  ; XX Corps - Tannenberg
  add-unit 8 12 8800 .06 0 0
  add-unit 9 12 8800 .06 0 0
  add-unit 10 13 8800 .06 0 0
  add-unit 8 13 8800 .06 0 0
  add-unit 8 11 8800 .06 0 0
  
  
  ;  Russian 1st
  ;  IV Corps
  add-approaching-unit 35 25 10000 ruseffectiveness 1 1 0
  add-approaching-unit 35 25 10000 ruseffectiveness 1 1 0
  add-approaching-unit 35 25 10000 ruseffectiveness 1 1 0
  add-approaching-unit 35 25 10000 ruseffectiveness 1 1 0
  add-approaching-unit 35 25 10000 ruseffectiveness 1 1 0
  
  ;  III Corps
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 3
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 3
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 3
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 3
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 3
  
  ;  XX Corps
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 5
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 5
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 5
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 5
  add-approaching-unit 37 25 10000 ruseffectiveness 1 1 5
  
  
  ;Russian 2nd
  ; I Corps - Just south of Soldau
  add-unit 9 5 10000 .02 1 2
  add-unit 10 6 10000 .02 1 2
  add-unit 10 7 10000 .02 1 2
  add-unit 11 8 10000 .02 1 2
  add-unit 11 9 10000 .02 1 2
  
  ; VI Corps was harldy a factor, so not included
  
  ; XIII Corps - northeast of Orlau
  ;  1st ID
  add-unit 16 13 14800 .02 1 2
  ;  36th ID
  add-unit 17 13 14800 .02 1 2
  
  
  ; XV Corps - Just south of Orlau
  add-unit 14 10 10000 .02 1 2
  add-unit 15 11 10000 .02 1 2
  add-unit 15 12 10000 .02 1 2
  add-unit 16 12 10000 .02 1 2
  add-unit 17 13 10000 .02 1 2
  
  
  ; XXIII Corps
  ;  3rd Guard ID - east of 2nd ID
  add-unit 15 8 14800 .02 1 2
  ;  2nd ID - North of Lippau and South of Janushken
  add-unit 15 7 14800 .02 1 2
end

;; Generate a unit at the given position with the given troops, effectiveness, and allegiance.
to add-unit [ xco yco introops effectiveness allegiance ingroup]
  let loc-set 0
  while [ loc-set = 0 ] [ask patch xco yco [ ask cells-here [ if-else terrain != 1 [set loc-set 1] [set yco yco + 1]]]]
  ask patch xco yco [ sprout-units 1 [ display-unit allegiance 
    set team allegiance
    set troops introops
    set maxTroops troops
    set aimedWeapons effectiveness
    set target [-1 -1]
    set group ingroup
    set neighb-enemies []
    set distanceNorth 0
    set isEngaged false]]
end

;; Generate an off-screen unit.  xco and yco represent the space in which they will appear.
to add-approaching-unit [ xco yco introops effectiveness allegiance ingroup miles]
  let loc-set 0
  while [ loc-set = 0 ] [ask patch xco yco [ ask cells-here [ if-else terrain != 1 [set loc-set 1] [set yco yco + 1]]]]
  ask patch xco yco [ sprout-units 1 [ display-unit allegiance 
    set team allegiance
    set troops introops
    set maxTroops troops
    set aimedWeapons effectiveness
    set target [-1 -1]
    set group ingroup
    set neighb-enemies []
    set travelTime miles
    hide-turtle]]
end

to-report report-adjacent-divisions
      ifelse pxcor mod 2 = 0
      [ report divisions-on cells-on patches at-points [[0 1] [1 0] [1 -1] [0 -1] [-1 -1] [-1 0]] ]
      [ report divisions-on cells-on patches at-points [[0 1] [1 1] [1  0] [0 -1] [-1  0] [-1 1]] ]
end

;;;;;;;;;;;;;;;;;;;;Code that can probably be phased out goes down here
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; An attacker attacks the defender with a proportion of his firepower.
to attack [attacker defender proportion]
  
  ;Unaimed fire calculations performed first
  ;Attacker performs attrition on the defender first
  
  ;let defendDamage ([troops] of defender * ([aimedWeapons] of defender))
  let attackDamage round ([troops] of attacker * proportion * ([aimedWeapons] of attacker))
  
  if-else [team] of attacker = 0 [ set russian-losses russian-losses + attackDamage ]
  [set german-losses (german-losses + attackDamage)]
  
  ;ask attacker [set troops (troops - defendDamage)]
  ask defender [set troops (round troops - (attackDamage))]
  
  ;if [troops] of attacker < 0 [ ask attacker [die] ]
  
  if-else [troops] of defender < 0 [ ask defender [die] ]
  [
    if ([troops] of defender < (0.45 * [maxTroops] of defender) and [team] of defender = 1) [
      ask patch [xcor] of defender [ycor] of defender [ sprout-dead-units 1 [
        set troops [troops] of defender
        set team [team] of defender
        display-unit team
        set russian-losses (russian-losses + [troops] of defender)
      ]
      ]
      ask defender [die]
    ]
  ]
end

to add-rail-link [ xa ya xb yb ]
  ask patch xa ya [ 
    ask cells-here [ create-rail-link-with one-of cells-on patch xb yb [ set color yellow set shape "line2" ]]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
242
35
1113
612
-1
-1
21.0
1
10
1
1
1
0
0
0
1
0
40
0
25
1
1
1
ticks
30.0

BUTTON
73
44
154
77
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
73
114
154
147
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
73
79
154
112
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
25
173
210
206
mapSize
mapSize
1
50
21
1
1
NIL
HORIZONTAL

SLIDER
25
237
210
270
headstart
headstart
26
29
26.8
.2
1
NIL
HORIZONTAL

SLIDER
24
306
209
339
ruseffectiveness
ruseffectiveness
0
.1
0.035
.005
1
NIL
HORIZONTAL

TEXTBOX
26
157
139
175
Map Size
11
0.0
1

TEXTBOX
25
218
230
246
Russian Arrival Time
11
0.0
1

TEXTBOX
26
287
203
315
Russian 1st Army effectiveness
11
0.0
1

PLOT
19
371
219
502
Troops Remaining
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -14070903 true "" "plot sum [troops] of units with [team = 0]"
"pen-1" 1.0 0 -2674135 true "" "plot sum [troops] of units with [team = 1]"

@#$#@#$#@
## WHAT IS IT?

This is a simulation of the battle of Tannenberg in 1914.

## HOW IT WORKS

Since patches are square, we must represent the cells as turtles instead.

Each patch sprouts a "cell" turtle.  Turtles on even patch columns are offset down by half a patch.  (Since the south boundary of a patch is part of the patch, this does not move the turtle to a different patch.)

The resulting lattice has the correct structure, but distances and angles are distorted. So the hexagons aren't actually regular, but it doesn't matter as long as you don't try to use primitives such as `distance` and `towards`.

Also, you must use the `hex-neighbors` variable instead of the built-in `neighbors` and `neighbors4` reporters.

## RELATED MODELS

This example is for stationary cells.  Hex Turtles Example shows how to make turtles that move along a hexagonal lattice.  (It would also be possible to combine both techniques in a single model.)

Link Lattice Example and Lattice-Walking Turtles Example demonstrate another approach to making a hexagonal lattice, using links instead of just patches.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

hex
false
0
Polygon -7500403 true true 0 150 75 30 225 30 300 150 225 270 75 270

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

unit
false
14
Rectangle -16777216 true true 30 75 270 240
Rectangle -1 true false 45 90 255 225
Line -16777216 true 45 90 255 225
Line -16777216 true 45 225 255 90

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.3
@#$#@#$#@
setup1
repeat 20 [ go ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

line2
0.0
-0.2 1 1.0 0.0
0.0 1 4.0 4.0 2.0 2.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
