#!/usr/bin/python
import FastFiz
import Rules

print FastFiz.getFastFizVersion()
shotParams = FastFiz.ShotParams()
shotParams.v = 4
shotParams.a = 6
shotParams.b = 8
shotParams.phi = 10
shotParams.theta = 11

gameShot = Rules.GameShot()
gameShot.params = shotParams
gameShot.cue_x = 1
gameShot.cue_y = 2

gameState = Rules.GameState.RackedState(Rules.GT_EIGHTBALL)
gameState.executeShot(gameShot)

print shotParams
print Rules.getRulesVersion()

#print "Comparing two initial game States"
#print gameState.toString()
gameState = Rules.GameState.RackedState(Rules.GT_EIGHTBALL)
gameStateString = gameState.toString()
#print gameStateString
newGameState = Rules.GameState.Factory(gameStateString)
newGameStateString = newGameState.toString()
#print newGameStateString

print "Onto tests version 2"
print "Without the Eight-Ball Specific Stuff Appended"
constructorString = "1 4 0 0 1 1 1 0.028575 1 0 0.558 1.69935"
constructorString = "1 4 0 0 1 1 0.028575 1 0 0.558 1.69935"
newerGameState = Rules.GameState.Factory(constructorString)
print constructorString
print newerGameState.toString()
print "With the Eight-Ball Specific Stuff Appended"
constructorString = "1 4 0 0 1 1 1 0.028575 1 0 0.558 1.69935 0 1"
constructorString = "1 4 0 0 1 1 0.028575 1 0 0.558 1.69935 0 1"
newerGameState = Rules.GameState.Factory(constructorString)
print constructorString
print newerGameState.toString()
print newerGameState.isOpenTable()
print newerGameState.playingSolids()



