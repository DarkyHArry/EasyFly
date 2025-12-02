import SwiftUI

/// Representa a tela de pesquisa de passagens, incluindo o seletor de data e destino.
struct SearchFlightsView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State private var departureCity: String = ""
    @State private var arrivalCity: String = ""
    @State private var isRoundTrip: Bool = true // Estado para "Ida e Volta" ou "Só Ida"
    
    // Simulação de datas selecionadas
    @State private var selectedDate1: Date? = Calendar.current.date(byAdding: .day, value: 3, to: Date())
    @State private var selectedDate2: Date? = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    
    private var accentColor: Color {
        Color(red: 1.0, green: 0.76, blue: 0.16) // Laranja/Amarelo
    }
    
    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).uppercased()
    }
    
    // MARK: - Componente de Campo de Entrada Personalizado
    struct InputField: View {
        var placeholder: String
        @Binding var text: String
        var iconName: String
        
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.gray)
                TextField(placeholder, text: $text)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    var body: some View {
        VStack {
            // MARK: - Título
            Text("Book a Flight")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 10)
            
            // MARK: - Campos de Cidade
            VStack(spacing: 15) {
                InputField(placeholder: "Departure City", text: $departureCity, iconName: "mappin.circle.fill")
                InputField(placeholder: "Arrival City", text: $arrivalCity, iconName: "mappin.circle.fill")
            }
            .padding()
            
            // MARK: - Seleção de Tipo de Viagem
            HStack(spacing: 20) {
                // Round Trip
                RadioButton(label: "Round Trip", isSelected: isRoundTrip) {
                    isRoundTrip = true
                }
                // One Way
                RadioButton(label: "One Way", isSelected: !isRoundTrip) {
                    isRoundTrip = false
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            // MARK: - Calendário (Simplificado)
            VStack(spacing: 20) {
                // Header do Mês
                HStack {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                    }
                    Text(monthYearText)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    Button(action: {}) {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(colorScheme == .dark ? accentColor : Color.blue) // Cor de destaque
                .padding(.horizontal)
                
                // Dias da Semana
                let days = ["S", "M", "T", "W", "T", "F", "S"]
                HStack {
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .frame(maxWidth: .infinity)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Grade de Dias do Mês (Simulação)
                CalendarGrid(selectedDate1: $selectedDate1, selectedDate2: $selectedDate2, accentColor: accentColor)
            }
            .padding(.top, 10)
            .padding(.bottom, 40)
            
            Spacer()
            
            // MARK: - Botão de Busca
            Button(action: {
                // Ação: Iniciar a pesquisa de voos
            }) {
                Text("Search Flights")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentColor)
                    .cornerRadius(15)
                    .shadow(color: accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
    }
}

// MARK: - Componente RadioButton

struct RadioButton: View {
    var label: String
    var isSelected: Bool
    var action: () -> Void
    
    private var accentColor: Color {
        Color(red: 1.0, green: 0.76, blue: 0.16)
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? accentColor : .gray)
                Text(label)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Componente Calendar Grid (Simplificado)

struct CalendarGrid: View {
    @Binding var selectedDate1: Date?
    @Binding var selectedDate2: Date?
    var accentColor: Color
    
    // Simula os dias do calendário de abril de 2024
    let days: [String?] = [
        nil, nil, nil, "1", "2", "3", "4", "5", "6",
        "7", "8", "9", "10", "11", "12", "13",
        "14", "15", "16", "17", "18", "19", "20",
        "21", "22", "23", "24", "25", "26", "27",
        "28", "29", "30", "31"
    ]
    
    func isSelected(_ day: String?) -> Bool {
        // Simulação de seleção dos dias 10, 11 e 24, 20
        guard let day = day, let dayInt = Int(day) else { return false }
        return dayInt == 10 || dayInt == 11 || dayInt == 24 || dayInt == 20
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 15) {
            ForEach(days.indices, id: \.self) { index in
                if let day = days[index] {
                    Text(day)
                        .font(.subheadline)
                        .frame(width: 30, height: 30)
                        .background(isSelected(day) ? accentColor : Color.clear)
                        .clipShape(Circle())
                        .foregroundColor(isSelected(day) ? .black : .primary)
                        .overlay(
                            Circle()
                                .stroke(isSelected(day) ? accentColor : Color.clear, lineWidth: 2)
                        )
                } else {
                    Spacer() // Para preencher os dias vazios no início do mês
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct SearchFlightsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SearchFlightsView()
                .environment(\.colorScheme, .light)
                .previewDisplayName("Modo Claro")
            
            SearchFlightsView()
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Modo Escuro")
        }
    }
}
