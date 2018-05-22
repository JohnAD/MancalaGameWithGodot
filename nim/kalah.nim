#
# Kalah
#
# A mancala game variant popular in North America and Europe
#
# Rules and details: https://en.wikipedia.org/wiki/Kalah
#

import strutils
import turn_based_game
import negamax


#
# 1. define our game object and rules
#

type
  ScoringMethodRule = enum
    straight_scoring, greed_scoring, caution_scoring
  EogRule = enum
    traditional_sweep, empty_player_sweep, ending_player_sweep, never_sweep
  CaptureRule = enum
    capture_if_opp_full, always_capture, never_capture
  Kalah = ref object of Game
    board*: array[15, int]
    stones_per_pit*: int
    settings*: tuple[
      scoring_method: ScoringMethodRule,
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
    distance_to_store: array[3, int]
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
    (owner: HAND, next: [n,  n,  n], role: palm , opposite:  n, distance_to_store: [n,  n,  n]),
    (owner: USER, next: [n,  2,  2], role: house, opposite: 13, distance_to_store: [n,  6, 12]),
    (owner: USER, next: [n,  3,  3], role: house, opposite: 12, distance_to_store: [n,  5, 11]),
    (owner: USER, next: [n,  4,  4], role: house, opposite: 11, distance_to_store: [n,  4, 10]),
    (owner: USER, next: [n,  5,  5], role: house, opposite: 10, distance_to_store: [n,  3,  9]),
    (owner: USER, next: [n,  6,  6], role: house, opposite:  9, distance_to_store: [n,  2,  8]),
    (owner: USER, next: [n,  7,  8], role: house, opposite:  8, distance_to_store: [n,  1,  7]),
    (owner: USER, next: [n,  8,  8], role: store, opposite:  0, distance_to_store: [n,  n,  n]),
    (owner: AI  , next: [n,  9,  9], role: house, opposite:  6, distance_to_store: [n, 12,  6]),
    (owner: AI  , next: [n, 10, 10], role: house, opposite:  5, distance_to_store: [n, 11,  5]),
    (owner: AI  , next: [n, 11, 11], role: house, opposite:  4, distance_to_store: [n, 10,  4]),
    (owner: AI  , next: [n, 12, 12], role: house, opposite:  3, distance_to_store: [n,  9,  3]),
    (owner: AI  , next: [n, 13, 13], role: house, opposite:  2, distance_to_store: [n,  8,  2]),
    (owner: AI  , next: [n,  1, 14], role: house, opposite:  1, distance_to_store: [n,  7,  1]),
    (owner: AI  , next: [n,  1,  1], role: store, opposite:  0, distance_to_store: [n,  n,  n])
  ]
  ALL_PITS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

  OWN_PITS_FROM_STORE = [
      [ 0,  0,  0,  0, 0, 0],   # ignore
      [ 6,  5,  4,  3, 2, 1],   # USER
      [13, 12, 11, 10, 9, 8],   # AI
  ]

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

proc is_stopping_in_own_store(self: Kalah, pit_index: int): bool =
  let count = self.board[pit_index] mod 13  # if seeds > 12 then they wrap around board; so modulo 13
  return count == P[pit_index].distance_to_store[self.current_player_number]

proc immediate_moves(self: Kalah): seq[string] = 
  result = @[]
  for pit in HOUSE_LIST[self.current_player_number]:
    if self.board[pit] != 0:
      result.add($CHARMAP[pit])

proc recurse_moves(self: Kalah, move_list: seq[string], completed_list: var seq[string]): void =
  var last_move: char
  var last_pit: int
  var more_choices: seq[string]
  var next_moves: seq[string]

  let board_copy = self.board # make copy for later restoration

  for move in move_list:
    last_move = move[^1]
    last_pit = find(CHARMAP, last_move)
    if self.is_stopping_in_own_store(last_pit):
      # temporarily make the moves and recurse to find more
      discard self.make_move($last_move)
      more_choices = self.immediate_moves()
      if len(more_choices) > 0:
        next_moves = @[]
        for choice in more_choices:
          next_moves.add(move & choice)
        self.recurse_moves(next_moves, completed_list)
      else:
        completed_list.add(move)
      self.board = board_copy # restore board back
    else:
      completed_list.add(move)

method set_possible_moves*(self: Kalah, moves: var seq[string]) =
  moves = @[]
  self.recurse_moves(self.immediate_moves(), moves)


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
  else:
    self.winner_player_number = NO_WINNER_YET



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
  result.add("hand: $1\n".format(self.board[HAND]))
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


#     def caution_scoring(self, player):
#         raw_score = self.board[STORE_IDX[USER]]
#         if self.player==AI:
#             raw_score *= -1
#         return raw_score * 1000

#     def greed_scoring(self, player):
#         raw_score = self.board[STORE_IDX[AI]]
#         if self.player==USER:
#             raw_score *= -1
#         return raw_score * 1000


proc straight_strategic_scoring(self: Kalah, player_number: int): float =
  let opponent = self.next_player_number()
  return (self.board[STORE_IDX[player_number]] - self.board[STORE_IDX[opponent]]).float * 1000.0


method scoring*(self: Kalah): float =
  var
    strategic_score: float
  if self.winner_player_number == self.current_player_number:
    return 19000.0
  elif self.winner_player_number > 0: # somebody won, but not me
    return -19000.0
  elif self.winner_Player_number == STALEMATE:
    return -18000.0  # bad, but not a direct loss
  strategic_score = self.straight_strategic_scoring(self.current_Player_number)
  return strategic_score # plus, one day, a tactical score


method get_state*(self: Kalah): string =
  result = ""
  for pit in 0..<15:
    result.add(intToStr(self.board[pit], 2))
  result.add(intToStr(self.current_player_number, 1))

method restore_state*(self: Kalah, state: string): void =
  for pit in 0..<15:
    self.board[pit] = parseInt($(state[pit * 2] & state[pit * 2 + 1]))
  self.current_player_number = parseInt($state[30])


#
# for testing:
#
var game = Kalah()

var player_list: seq[Player] = @[]
player_list.add(Player(name: "A"))
player_list.add(NegamaxPlayer(name: "B", depth: 8)) # 9 is too slow
game.setup(4, player_list)

game.play()