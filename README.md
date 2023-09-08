# Eternova Quick Battles

## Uso de funciones

* Para EMPEZAR la batalla, llamar al metodo "startBattle(address opponent, uint[3] calldata troopsAmount)".

* Luego, para el resto de los turnos, hay que llamar a "requestBattle(uint id, uint[3] calldata troopsAmount)"
* Por ej: Jugador A desafia al jugador B:
    - PRIMER ROUND:
        - StartBattle (firmado por el jugador A).
        - RespondBattle (firmado por el jugador B).
    - SEGUNDO ROUND:
        - RequestBattle (firmado por el jugador B).
        - RespondBattle (firmado por el jugador A).
    - TERCER ROUND:
        - RequestBattle (firmado por el jugador A).
        - RespondBattle (firmado por el jugador B). 

## Metodos para consulta de datos

* "getPublicBattleData(uint id)": unicamente llamable por el creador de la batalla o el contrincante. Devuelve la información "publica" de la batalla, es decir, solo los datos propios de quien llama a la función.

* "getUserBattleData(address user, uint limit, uint offset)": devuelve el listado de batallas (creador, contrincante, round actual, usuario pendiente de movimiento y ganador -si hubiera, sino zero_address-) del usuario.


## Test

Run tests
```bash
$ npm run test
```

Run coverage
```bash
$ npm run coverage
```
