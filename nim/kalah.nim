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
# 1. define our game object and rules
#

type
  EogRule = enum
    traditional_sweep, empty_player_sweep, ending_player_sweep, never_sweep
  CaptureRule = enum
    capture_if_opp_full, always_capture, never_capture
  Kalah = ref object of Game
    board*: array[15, int]
    stones_per_pit*: int
    settings*: tuple[
      eog_rule: EogRule,
      capture_rule: CaptureRule
    ]

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
    owner: int,
    next: array[3, int],
    role: PitRole,
    opposite: int,
    distribute: array[3, int]
  ]

const
  HAND = 0
  USER = 1
  AI = 2
  PLAYER_LIST = [USER, AI]

  HOUSE_LIST = [
    [ 0, 0,  0,  0,  0,  0],  # ignore
    [ 1, 2,  3,  4,  5,  6],  # USER
    [ 13, 12, 11, 10, 9, 8]   # AI
    # [ 8, 9, 10, 11, 12, 13]   # AI
  ]
  STORE_IDX = [
    0,   # HAND
    7,   # USER
    14   # AI
  ]

  n = 0   # nil value in integer form

  P: array[15, PitDetail] = [
    (owner: HAND, next: [n,  n,  n], role: palm , opposite:  n, distribute: [n,  n,  n]),
    (owner: USER, next: [n,  2,  2], role: house, opposite: 13, distribute: [n,  6, 12]),
    (owner: USER, next: [n,  3,  3], role: house, opposite: 12, distribute: [n,  5, 11]),
    (owner: USER, next: [n,  4,  4], role: house, opposite: 11, distribute: [n,  4, 10]),
    (owner: USER, next: [n,  5,  5], role: house, opposite: 10, distribute: [n,  3,  9]),
    (owner: USER, next: [n,  6,  6], role: house, opposite:  9, distribute: [n,  2,  8]),
    (owner: USER, next: [n,  7,  8], role: house, opposite:  8, distribute: [n,  1,  7]),
    (owner: USER, next: [n,  8,  8], role: store, opposite:  0, distribute: [n,  n,  n]),
    (owner: AI  , next: [n,  9,  9], role: house, opposite:  6, distribute: [n, 12,  6]),
    (owner: AI  , next: [n, 10, 10], role: house, opposite:  5, distribute: [n, 11,  5]),
    (owner: AI  , next: [n, 11, 11], role: house, opposite:  4, distribute: [n, 10,  4]),
    (owner: AI  , next: [n, 12, 12], role: house, opposite:  3, distribute: [n,  9,  3]),
    (owner: AI  , next: [n, 13, 13], role: house, opposite:  2, distribute: [n,  8,  2]),
    (owner: AI  , next: [n,  1, 14], role: house, opposite:  1, distribute: [n,  7,  1]),
    (owner: AI  , next: [n,  1,  1], role: store, opposite:  0, distribute: [n,  n,  n])
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

method setup*(self: Kalah, per_pit: int, players: seq[Player]) {.base.} =
  self.default_setup(players)
  self.stones_per_pit = per_pit
  self.board[HAND] = 0
  self.board[STORE_IDX[AI]] = 0
  self.board[STORE_IDX[USER]] = 0
  for pl in PLAYER_LIST:
    for pit in HOUSE_LIST[pl]:
      self.board[pit] = self.stones_per_pit


proc immediate_moves(self: Kalah): seq[string] = 
  result = @[]
  for pit in HOUSE_LIST[self.current_player_number]:
    if self.board[pit] != 0:
      result.add($CHARMAP[pit])

method set_possible_moves*(self: Kalah, moves: var seq[string]) =
  moves = @[]
  var immediate = immediate_moves(self)
  # for move in immediate:
  #   final_list = recurse_moves(self, move, moves)
  moves = immediate


method determine_winner*(self: Kalah) =
  var end_of_game = false
  var sum: int
  for pl in PLAYER_LIST:
    sum = 0
    for pit in HOUSE_LIST[pl]:
      sum += self.board[pit]
    if sum == 0:
      end_of_game = true
  if end_of_game:
    if self.board[STORE_IDX[USER]] > self.board[STORE_IDX[AI]]:
      self.winner_player_number = USER
    elif self.board[STORE_IDX[USER]] < self.board[STORE_IDX[AI]]:
      self.winner_player_number = AI
    else:
      self.winner_player_number = STALEMATE



method make_move*(self: Kalah, move: string): string =
  result = "move (" & move & ") made"
  var submove: char
  for submove in move:
    var start_pit = find(CHARMAP, submove)
    var current_pit = start_pit
    #
    # scoop up the house chosen
    #
    self.board[HAND] = self.board[current_pit]
    self.board[current_pit] = 0
    #
    # drop the seeds into the pits
    #
    for ctr in 0..<self.board[HAND]:
      #
      # go to next pit
      #
      current_pit = P[current_pit].next[self.current_player_number]
      #
      # drop one stone
      #
      self.board[HAND] -= 1
      self.board[current_pit] += 1
    #
    # now we have dropped the stones; capture if possible
    #
    if self.settings.capture_rule == capture_if_opp_full:
      if self.board[current_pit] == 1:  # landed in what was an empty pit
        # note: a STORE's opposite is the empty hand, so is always zero
        if self.board[P[current_pit].opposite] > 0: # opposite house is not empty
          if P[current_pit].owner == self.current_player_number: # we own the house
            #
            # do the capture
            #
            self.board[HAND] += self.board[current_pit]
            self.board[current_pit] = 0
            self.board[HAND] += self.board[P[current_pit].opposite]
            self.board[P[current_pit].opposite] = 0
            self.board[STORE_IDX[self.current_player_number]] += self.board[HAND]
            self.board[HAND] = 0
            result.add(", which includes capture from " & $CHAR_MAP[current_pit])
    elif self.settings.capture_rule == always_capture:
      if self.board[current_pit] == 1:  # landed in what was an empty pit
        if P[current_pit].role == house: # landed in house, not a store
          if P[current_pit].owner == self.current_player_number: # we own the house
            #
            # do the capture
            #
            self.board[HAND] += self.board[current_pit]
            self.board[current_pit] = 0
            if self.board[P[current_pit].opposite] > 0:
              self.board[HAND] += self.board[P[current_pit].opposite]
              self.board[P[current_pit].opposite] = 0
            self.board[STORE_IDX[self.current_player_number]] += self.board[HAND]
            self.board[HAND] = 0
            result.add(", which includes capture from " & $CHAR_MAP[current_pit])
    # ignore the never_capture setting since nothing happends
    #
    # check for end-of-game and scoop if needed
    #
    self.determine_winner()
    if self.winner_player_number != NO_WINNER_YET:
      # traditional rule: each player gets own stones
      if self.settings.eog_rule == traditional_sweep:
        for pl in PLAYER_LIST:
          for pit in HOUSE_LIST[pl]:
            if self.board[pit] > 0:
              self.board[HAND] += self.board[pit]
              self.board[pit] = 0
          self.board[STORE_IDX[pl]] += self.board[HAND]
          self.board[HAND] = 0
        result.add(", which includes end-of-game sweep")
        self.determine_winner() # this MUST be called to again to get true winner
      elif self.settings.eog_rule == empty_player_sweep:
        # common variant: the player with no stones in houses, gets all
        var empty_player: int = USER
        for pit in HOUSE_LIST[USER]:
          if self.board[pit] > 0:
            empty_player = AI
            break
        for pl in PLAYER_LIST:
          for pit in HOUSE_LIST[pl]:
            if self.board[pit] > 0:
              self.board[HAND] += self.board[pit]
              self.board[pit] = 0
          self.board[STORE_IDX[empty_player]] += self.board[HAND]
          self.board[HAND] = 0
        result.add(", which includes end-of-game sweep")
        self.determine_winner() # this MUST be called to again to get true winner
      elif self.settings.eog_rule == ending_player_sweep:
        # the player who ended the game gets the stones
        for pl in PLAYER_LIST:
          for pit in HOUSE_LIST[pl]:
            if self.board[pit] > 0:
              self.board[HAND] += self.board[pit]
              self.board[pit] = 0
          self.board[STORE_IDX[self.current_player_number]] += self.board[HAND]
          self.board[HAND] = 0
        result.add(", which includes end-of-game sweep")
        self.determine_winner() # this MUST be called to again to get true winner
      # ignore self.settings.eog_urle == never_sweep because nothing happens

method status*(self: Kalah): string =
  result = ""
  result.add("hand: {}\n".format(self.board[HAND]))
  result.add("board:\n")
  result.add("           a    b    c    d    e    f      AI\n")
  for pl in [AI, HAND, USER]:
    if pl==HAND:
      result.add("     [$1]              ".format(intToStr(self.board[STORE_IDX[AI]], 2)))
      result.add("               [$1]\n".format(intToStr(self.board[STORE_IDX[USER]], 2)))
    else:
      result.add("         ")
      for pit in HOUSE_LIST[pl]:
        result.add("[" & intToStr(self.board[pit], 2) & "] ")
      result.add("\n")
  result.add("           F    E    D    C    B    A      USER\n")



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