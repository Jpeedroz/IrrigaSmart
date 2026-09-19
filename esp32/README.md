# ESP32 - IrrigaSmart

Código responsável pelo funcionamento do ESP32 no sistema IrrigaSmart.

## Funções

- Conectar o ESP32 à rede Wi-Fi;
- Ler o sensor de umidade do solo;
- Ler a temperatura;
- Ler o sensor de vazão;
- Controlar a bomba por meio de um relé;
- Enviar os dados para o backend;
- Receber comandos do sistema, quando necessário.

## Fluxo

Sensores → ESP32 → Wi-Fi → Backend → Banco de Dados

Controle da irrigação:

ESP32 → Relé → Bomba d'água
