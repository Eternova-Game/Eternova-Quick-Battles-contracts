# Eternova Quick Battles

## Methos

* To start a battle, call method "startBattle(address opponent, uint[3] calldata troopsAmount)".

* Then, for the rest of the turns, you need to call "requestBattle(uint id, uint[3] calldata troopsAmount)"
* Ex: Player A battles al player B:
    - FIRST ROUND:
        - StartBattle (player A).
        - RespondBattle (player B).
    - SECOND ROUND:
        - RequestBattle (player B).
        - RespondBattle (player A).
    - THIRD ROUND:
        - RequestBattle (player A).
        - RespondBattle (player B). 

## Read data

* "getPublicBattleData(uint id)": only callable by the creator of the battle or the opponent. Returns the "public" information of the battle, that is, only the data of the person calling the function.

* "getUserBattleData(address user, uint limit, uint offset)": returns the list of battles (creator, opponent, current round, user pending movement and winner - if any -) of the user.


## Test

Run tests
```bash
$ npm run test
```

Run coverage
```bash
$ npm run coverage
```
