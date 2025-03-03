import SwiftUI

struct SecondView: View {
    @Binding var savedProjects: [SavedProject]
    @Binding var selectedImage: Image?
    @Binding var goals: [Goal]
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    @Binding var cells: [Cell]
    @Binding var showGrid: Bool
    @Binding var currentProjectId: UUID?
    @Binding var projectName: String
    @Binding var originalUIImage: UIImage?
    @Binding var selectedDeadline: Date?
    
    // Добавляем функцию для сохранения
    private func saveProjects() {
        guard let encoded = try? JSONEncoder().encode(savedProjects) else { return }
        UserDefaults.standard.set(encoded, forKey: "savedProjects")
        UserDefaults.standard.synchronize() // Принудительно сохраняем
    }
    
    // И добавим функцию загрузки проектов
    private func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: "savedProjects"),
              let decoded = try? JSONDecoder().decode([SavedProject].self, from: data) else {
            return
        }
        savedProjects = decoded
    }
    
    private func restoreProject(_ project: SavedProject) {
        guard let uiImage = UIImage(data: project.imageData) else { return }
        
        // Сначала очищаем предыдущее состояние
        selectedImage = nil
        goals.removeAll()
        cells.removeAll()
        projectName = ""  // Важно очистить имя проекта!
        
        // Затем восстанавливаем проект
        selectedImage = Image(uiImage: uiImage)
        goals = project.goals
        cells = project.cells
        showGrid = project.showGrid
        projectName = project.projectName  // Восстанавливаем имя проекта
        currentProjectId = project.id      // Устанавливаем правильный ID
        originalUIImage = uiImage          // Сохраняем оригинальное изображение
        selectedDeadline = project.deadline  // Восстанавливаем дедлайн
        
        isPresented = false
    }
    
    private func getImage(from data: Data) -> Image {
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
    
    private func getDaysRemaining(for date: Date?) -> String {
        guard let deadline = date else { return "" }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        guard let days = components.day else { return "" }
        
        if days < 0 {
            return "Expired"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day left"
        } else {
            return "\(days) days left"
        }
    }
    
    private func getDeadlineColor(for date: Date?) -> Color {
        guard let deadline = date else { return .white }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        guard let days = components.day else { return .white }
        
        if days < 0 {
            return .red
        } else if days <= 3 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customDarkNavy  // Заменяем Image("background") на сплошной цвет
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(savedProjects) { project in
                            ZStack(alignment: .topTrailing) {
                                VStack(spacing: 4) {
                                    getImage(from: project.thumbnailData)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width * 0.4,
                                               height: UIScreen.main.bounds.width * 0.4)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    Text(project.projectName)
                                        .font(.system(size: UIScreen.main.bounds.width * 0.035))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if let deadline = project.deadline {
                                        Text(getDaysRemaining(for: deadline))
                                            .font(.system(size: UIScreen.main.bounds.width * 0.03))
                                            .foregroundColor(getDeadlineColor(for: deadline))
                                            .padding(.vertical, 2)
                                            .padding(.horizontal, 8)
                                            .background(Color.customNavy)
                                            .cornerRadius(5)
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width * 0.43)
                                .padding(.vertical, 8)
                                .background(Color.customNavy)
                                .cornerRadius(10)
                                .onTapGesture {
                                    restoreProject(project)
                                }
                                
                                Button(action: {
                                    if let index = savedProjects.firstIndex(where: { $0.id == project.id }) {
                                        savedProjects.remove(at: index)
                                        saveProjects()
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.red)
                                        .background(Color.white.clipShape(Circle()))
                                }
                                .offset(x: 10, y: -10)
                            }
                        }
                    }
                    .padding()
                    .padding(.top, 60) // Увеличиваем отступ сверху
                }
            }
            .navigationTitle("My Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            // Остаемся на текущей странице
                        }) {
                            Label("My Goals", systemImage: "list.bullet")
                                .foregroundColor(.gray)
                        }
                        .disabled(true)
                        
                        Button(action: {
                            if let url = URL(string: "https://familykorotkey.github.io/splitup-privacy-policy/") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("Privacy Policy", systemImage: "doc.text")
                        }
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Label("Main", systemImage: "house")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("My Goals")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadProjects() // Загружаем все проекты при открытии экрана
        }
    }
}

struct SecondView_Previews: PreviewProvider {
    @State static var mockProjects: [SavedProject] = []
    
    static var previews: some View {
        SecondView(
            savedProjects: .constant([]),  // Пустой массив для превью
            selectedImage: .constant(nil),
            goals: .constant([]),
            isPresented: .constant(true),
            cells: .constant([]),
            showGrid: .constant(true),
            currentProjectId: .constant(nil),
            projectName: .constant(""),
            originalUIImage: .constant(nil),
            selectedDeadline: .constant(nil)
        )
        .previewDevice("iPhone 14")  // Указываем конкретное устройство
    }
}
