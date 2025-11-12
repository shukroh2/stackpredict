# StackPredict - Decentralized Prediction Market

A decentralized prediction market smart contract built on the Stacks blockchain using Clarity. Users can create events, place bets on binary outcomes (YES/NO), and claim rewards based on their predictions.

## Features

- **Create Prediction Events**: Any user can create a new prediction event with a question
- **Place Bets**: Users can bet STX tokens on YES or NO outcomes
- **Resolve Events**: Event creators or admins can close events and declare the winning side
- **Claim Rewards**: Users who predicted correctly can claim proportional rewards from the losing pool
- **Platform Fees**: 2% platform fee on rewards (configurable)
- **Admin Controls**: Owner can withdraw accumulated fees

## Contract Architecture

### Data Structures

#### Events Map
Stores prediction events with:
- Creator principal
- Question (128 ASCII characters max)
- YES pool balance
- NO pool balance
- Open/closed status
- Winning side (optional until resolved)

#### Bets Map
Tracks individual user bets with:
- Event ID + User principal (composite key)
- Bet side (YES = true, NO = false)
- Bet amount in microSTX
- Claim status

### Error Codes

| Code | Description |
|------|-------------|
| u100 | ERR_NOT_OWNER - Only owner can perform this action |
| u101 | ERR_NOT_FOUND - Event or bet not found |
| u102 | ERR_EVENT_CLOSED - Cannot bet on closed events |
| u103 | ERR_EVENT_OPEN - Event still open, cannot claim |
| u104 | ERR_INVALID_SIDE - Invalid bet amount |
| u105 | ERR_ALREADY_VOTED - User already has a bet on this event |
| u106 | ERR_NO_BALANCE - Insufficient balance or no winnings |


**Example:**
```clarity
(create-event "Will Bitcoin reach $100k by end of 2025?")
