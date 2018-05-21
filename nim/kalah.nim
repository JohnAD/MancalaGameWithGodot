#
# Kalah
#
# A mancala game variant popular in North America and Europe
#
# Rules and details: https://en.wikipedia.org/wiki/Kalah
#

import strutils
import turn_based_game


#
# 1. define our game object
#

type
  Kalah = ref object of Game
    board*: array[15, int]
    stones_per_pit: int

#   BOARD LAYOUT
#
#     13   12   11   10   09   08        AI
# 14                               07
#     01   02   03   04   05   06        USER
#
# HAND = 00

#   BOARD LAYOUT (game standard letters)
#
#      a    b    c    d    e    f        AI
#  Y                                X
#      F    E    D    C    B    A        USER
#
# HAND = H

const
  CHARMAP = "HFEDCBAXfedcbaY"

type
  PitRole = enum
    house, store, palm
  PitDetail = tuple[
    owner: int
    next: array[3, int]
    role: PitRole
    opposite: int
    distribute: array[3, int]
  ]

const
  HAND = 0
  USER = 1
  AI = 2

  HOUSE_LIST = [
    [ 0, 0,  0,  0,  0,  0],  # ignore
    [ 1, 2,  3,  4,  5,  6],  # USER
    [ 8, 9, 10, 11, 12, 13]   # AI
  ]
  STORE_IDX = [
    0,   # HAND
    7,   # USER
    14   # AI
  ]

  n = 0   # nil value in integer form

  P = [  # PIT DETAILS
    PitDetail(owner: HAND, next: [n,  n,  n], role, palm , opposite:  n, distribute: [n,  n,  n]),
    PitDetail(owner: USER, next: [n,  2,  2], role: house, opposite: 13, distribute: [n,  6, 12]),
    PitDetail(owner: USER, next: [n,  3,  3], role: house, opposite: 12, distribute: [n,  5, 11]),
    PitDetail(owner: USER, next: [n,  4,  4], role: house, opposite: 11, distribute: [n,  4, 10]),
    PitDetail(owner: USER, next: [n,  5,  5], role: house, opposite: 10, distribute: [n,  3,  9]),
    PitDetail(owner: USER, next: [n,  6,  6], role: house, opposite:  9, distribute: [n,  2,  8]),
    PitDetail(owner: USER, next: [n,  7,  8], role: house, opposite:  8, distribute: [n,  1,  7]),
    PitDetail(owner: USER, next: [n,  8,  8], role: store, opposite:  0, distribute: [n,  n,  n]),
    PitDetail(owner: AI  , next: [n,  9,  9], role: house, opposite:  6, distribute: [n, 12,  6]),
    PitDetail(owner: AI  , next: [n, 10, 10], role: house, opposite:  5, distribute: [n, 11,  5]),
    PitDetail(owner: AI  , next: [n, 11, 11], role: house, opposite:  4, distribute: [n, 10,  4]),
    PitDetail(owner: AI  , next: [n, 12, 12], role: house, opposite:  3, distribute: [n,  9,  3]),
    PitDetail(owner: AI  , next: [n, 13, 13], role: house, opposite:  2, distribute: [n,  8,  2]),
    PitDetail(owner: AI  , next: [n,  1, 14], role: house, opposite:  1, distribute: [n,  7,  1]),
    PitDetail(owner: AI  , next: [n,  1,  1], role: store, opposite:  0, distribute: [n,  n,  n])
  ]
  ALL_PITS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

  OWN_PITS_FROM_STORE = [
      [ 0,  0,  0,  0, 0, 0],   # ignore
      [ 6,  5,  4,  3, 2, 1],   # USER
      [13, 12, 11, 10, 9, 8],   # AI
  ]

  ACTION = "action"
  COUNT = "count"
  LOC = "loc"

  BALANCE = 0
  GREED = 1
  CAUTION = 2

  EMPTY = 0
  FULL = 1


#
#  2. add our rules (methods)
#

method setup*(self: Kalah, per_pit: int, players: seq[Player]) =
  self.default_setup(players)
  self.board = [0, 4, 4, 4, 4, 4, 4,]
  self.stones_per_pit = per_pit
  self.board[HAND] = 0
  for pit in ALL_PITS:
    self.board[pit] = self.stones_per_pit


method immediate_moves(self: Kalah): seq[string] = 
  result = @[]
  for pit in HOUSE_LIST[self.current_player_number]:
    if self.board[pit] != 0:
      result.append($CHARMAP[pit])

method set_possible_moves*(self: Kalah, moves: var seq[string]) =
  result = @[]
  var immediate = immediate_moves(self)
  for move in immediate:
    final_list = recurse_moves(self, move, result)


# TODO continue here

method make_move*(self: Kalah, move: string): string =
  var count = move.parseInt()
  self.pile -= count  # remove bones.
  return "$# flags removed.".format([count])

method determine_winner*(self: Kalah) =
  if self.winner_player_number > 0:
    return
  if self.pile <= 0:
    self.winner_player_number = self.current_player_number

# the following method is not _required_, but makes it nicer to read
method status*(self: Kalah): string =
  "$# flags available.".format([self.pile])

#
# 3. invoke the new game object
#

var game = Kalah()

#
# 4. reset (start) a new game with, in this case, 3 players
#

game.setup(4, @[Player(name: "A"), Player(name: "B")])

#
# 5. play the game at a terminal
#

game.play()