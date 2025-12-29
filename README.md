# Instalador Autônomo de Softwares (PowerShell)

Ferramenta desenvolvida em **PowerShell** com interface gráfica (WPF) para automatizar a instalação de softwares essenciais em ambientes Windows corporativos.

O projeto foi criado para substituir um processo manual, repetitivo e sujeito a falhas, trazendo mais **agilidade, padronização e confiabilidade** na preparação de máquinas.

---

## 🚀 Funcionalidades

- Interface gráfica amigável (WPF)
- Instalação automática via **Winget**
- Fallback inteligente para instaladores locais (EXE)
- Suporte a instalação silenciosa
- Tratamento de falhas e múltiplas tentativas
- Fluxos específicos para softwares corporativos
- Log detalhado em arquivo e na interface
- Opções adicionais:
  - Renomear computador
  - Reiniciar ao final do processo

---

## 🧠 Aprendizados aplicados

- Automação robusta com validação de sucesso
- Gerenciamento de processos (Start-Process, ExitCode)
- Integração Winget + instaladores locais
- Tratamento de exceções e falhas reais
- Desenvolvimento de GUI em PowerShell
- Boas práticas para scripts executáveis (ps2exe)

---

## 🖥️ Tecnologias utilizadas

- PowerShell
- Windows Presentation Foundation (WPF)
- Winget
- MSI / EXE installers
- ps2exe

---

## 📂 Estrutura do projeto

Diretório destinado aos instaladores locais (EXE).  
Por motivos de licença e segurança, os arquivos **não são versionados** neste repositório.

---

## ⚠️ Observações

- O script deve ser executado como **Administrador**
- Alguns softwares corporativos podem exigir ativação manual após a instalação
- Adaptável para diferentes ambientes e catálogos de software

---

## 📸 Screenshots



![Windows-screen0 (online-video-cutter com)](https://github.com/user-attachments/assets/0554d579-ed8f-42fa-b10e-b69160d31bff)

*- Aplicativo Iniciando*


![Windows-screen0 (online-video-cutter com) (3)](https://github.com/user-attachments/assets/81feba31-9492-4540-888a-ee2e56d526af)

*- Efetuando as instalações*


![Windows-screen0 (online-video-cutter com) (1)](https://github.com/user-attachments/assets/c336c794-5333-4ed2-812d-6a29a4abc04b)

*- Finalizando as alterações e Reiniciando*


---

## 📌 Objetivo do projeto

Este projeto faz parte do meu **portfólio profissional**, demonstrando aplicação prática de automação para otimização de processos em ambientes de TI.

---

## 📄 Licença

Projeto disponibilizado para fins educacionais e demonstrativos.
