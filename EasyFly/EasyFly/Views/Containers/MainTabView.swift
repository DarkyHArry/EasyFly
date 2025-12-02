import SwiftUI

// MARK: - 1. Componente da Viagem

/// Um card estilizado que exibe os detalhes de uma próxima viagem.
struct TripCardView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Cor de destaque (laranja)
    private var accentColor: Color {
        Color(red: 1.0, green: 0.76, blue: 0.16)
    }
    
    // Cor de fundo adaptativa do card
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // Códigos IATA e Ícone do Avião
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("NFW") // Código da Cidade de Saída
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Text("New York") // Nome da Cidade
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "airplane")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                    .foregroundColor(accentColor)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("LHR") // Código da Cidade de Chegada
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    Text("London") // Nome da Cidade
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            // Horário e Status
            HStack {
                Text("6:20 PM") // Horário
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("On Time")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(accentColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 2. Tela Principal (HomeView)

/// A primeira aba da aplicação, contendo a barra de pesquisa e a lista de viagens.
struct HomeView: View {
    @Environment(\.colorScheme) var colorScheme
    
    private var primaryColor: Color {
        Color(red: 0.1, green: 0.15, blue: 0.2) // Azul escuro
    }
    
    private var accentColor: Color {
        Color(red: 1.0, green: 0.76, blue: 0.16) // Laranja/Amarelo
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                
                // MARK: - Cabeçalho
                HStack {
                    Image(systemName: "airplane")
                        .foregroundColor(accentColor)
                    Text("EasyFly")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.top, 10)
                
                // MARK: - Botão de Busca de Voos
                Button(action: {
                    // Ação: Abrir a tela de pesquisa de voos (será uma navegação)
                }) {
                    HStack {
                        Image(systemName: "airplane")
                        Text("Where to?")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .padding()
                    .background(colorScheme == .dark ? accentColor : primaryColor)
                    .cornerRadius(15)
                }
                .padding(.vertical)
                
                // MARK: - Minhas Viagens
                Text("My Trips")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 20) {
                        TripCardView()
                        // Adicionar mais viagens aqui se necessário
                        TripCardView()
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)) // Exemplo de card diferente
                            .opacity(0.6)
                            .padding(.vertical, 20)
                    }
                    .padding(.top, 5)
                    .padding(.bottom, 80) // Espaço para a TabBar
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 3. Tab View Principal (MainTabView)

/// Container principal que hospeda a navegação por abas.
struct MainTabView: View {
    
    private var accentColor: Color {
        Color(red: 1.0, green: 0.76, blue: 0.16) // Laranja/Amarelo
    }
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            SearchFlightsView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            Text("Notifications Content")
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .accentColor(accentColor) // Define a cor do item selecionado na TabBar
    }
}

// Simple profile view with sign out
struct ProfileView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedEmail") private var loggedEmail: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(Color(red: 1.0, green: 0.76, blue: 0.16))

                Text(loggedEmail.isEmpty ? "Guest" : loggedEmail)
                    .font(.headline)

                Spacer()

                Button(role: .destructive) {
                    // Sign out — limpar dados de biometria também
                    BiometricManager.shared.clearBiometricData(for: loggedEmail)
                    loggedEmail = ""
                    isLoggedIn = false
                } label: {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView()
                .environment(\.colorScheme, .light)
                .previewDisplayName("Modo Claro")
            
            MainTabView()
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Modo Escuro")
        }
    }
}
