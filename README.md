# DMTN Gestão – iOS

App nativo iOS em Swift (SwiftUI) para gestão empresarial: estoque, vendas, caixa, atendimento via WhatsApp e leitor RFID Bluetooth.

## Stack

- Swift 5.9+ / SwiftUI
- iOS 16+
- Keychain para armazenamento seguro de sessão
- Core Bluetooth para leitor RFID BLE

## Estrutura

```
RfidApp/
├── Config/           # URL da API
├── Models/           # User, Product, Sale, ServiceOrder, NFe, etc.
├── Services/         # ApiClient, AuthService, RfidBluetoothManager
├── Theme/            # AppTheme (cores, tipografia)
├── ViewModels/       # OSViewModel
└── Views/            # Screens e Components
```

## Configuração

Em `Config/AppConfig.swift`:
- **Release:** `https://rfid.dmtn.com.br`
- **Debug:** `http://localhost:3000` (ou IP da máquina no dispositivo físico)

Para HTTP em dev, adicione em Info.plist:
- **App Transport Security** → **Allow Arbitrary Loads** = YES (apenas desenvolvimento)

## Build

Xcode 15+, abra `RfidApp/RfidApp.xcodeproj` e rode no simulador ou dispositivo.

## Funcionalidades

- Login e autenticação
- Dashboard com KPIs e gráfico de vendas
- Vendas, caixa, produtos, clientes
- Controle de estoque com alertas de falta
- Ordens de serviço (oficinas)
- NF-e e cupom fiscal
- Atendimento WhatsApp (conversas e pedidos)
- Leitor RFID Bluetooth UHF
- Suporte e configurações
