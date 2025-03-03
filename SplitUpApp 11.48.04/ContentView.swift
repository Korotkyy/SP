//
//  ContentView.swift
//  SplitUp
//
//  Created by FamilyKorotkey on 11.02.25.
//

import SwiftUI
import PhotosUI

enum GoalUnit: String, Codable, Identifiable, CaseIterable {
    // Количественные
    case pieces = "шт"
    case packs = "уп"
    case kilograms = "кг"
    case liters = "л"
    case meters = "м"
    
    // Денежные
    case euro = "€"
    case dollar = "$"
    case ruble = "₽"
    case tenge = "₸"
    
    // Временные
    case days = "дн"
    case weeks = "нед"
    case months = "мес"
    case hours = "ч"
    
    var id: String { self.rawValue }
}

struct Goal: Identifiable, Codable {
    var id = UUID()
    var text: String
    var totalNumber: String        // Общая сумма цели
    var remainingNumber: String    // Оставшаяся сумма
    var isCompleted: Bool = false
    var unit: GoalUnit
    var scale: Int = 1 // Добавляем масштаб: сколько единиц в одном квадрате
    
    // Вычисляемое свойство для отображения прогресса
    var progress: String {
        let total = Int(totalNumber) ?? 0
        let remaining = Int(remainingNumber) ?? 0
        let completed = total - remaining
        
        // Показываем масштаб только если он больше 1
        let scaleText = scale > 1 ? " (1□=\(scale)\(unit.rawValue))" : ""
        return "\(completed)/\(total)\(unit.rawValue)\(scaleText)"
    }
    
    // Добавляем вычисляемое свойство для реального количества квадратов
    var scaledSquares: Int {
        let total = Int(totalNumber) ?? 0
        return Int(ceil(Double(total) / Double(scale)))
    }
}

struct Cell: Codable {
    var isColored: Bool = false
    let position: Int
}

struct SavedProject: Identifiable, Codable {
    let id: UUID
    let imageData: Data        // Оригинальное изображение
    let thumbnailData: Data    // Маленькое изображение для превью
    let goals: [Goal]
    let projectName: String
    let cells: [Cell]
    let showGrid: Bool
    let deadline: Date?  // Добавляем опциональную дату дедлайна
}

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image? = nil
    @State private var projectName: String = ""
    @State private var selectedDeadline: Date?
    @State private var showDatePicker = false
    @State private var inputText: String = ""
    @State private var inputNumber: String = ""
    @State private var showInputs: Bool = false
    @State private var goals: [Goal] = []
    @State private var editingGoal: Goal?
    @State private var isEditing = false
    @State private var showGrid = false
    @State private var savedState: (Image?, [Goal])?
    @State private var cells: [Cell] = []
    @State private var coloredCount: Int = 0
    @State private var selectedGoalIndex = 0
    @State private var partialCompletion: String = ""
    @State private var savedProjects: [SavedProject] = []
    @State private var showingSecondView = false
    @AppStorage("savedProjects") private var savedProjectsData: Data = Data()
    @State private var showAlert = false
    @State private var selectedUnit: GoalUnit = .pieces
    @State private var showGoalsList = false
    @State private var showEditForm = false
    @State private var showingCalendar = false
    @State private var lastCellsState: [Cell]?
    @State private var lastGoalsState: [Goal]?
    @State private var currentProjectId: UUID?
    @State private var originalImageData: Data?
    @State private var originalUIImage: UIImage?
    @State private var isLayoutReady: Bool = false
    @State private var showActionButtons = true  // Новое состояние
    
    private var totalSquares: Int {
        goals.reduce(0) { $0 + $1.scaledSquares }
    }
    
    private func calculateGridDimensions() -> (rows: Int, columns: Int) {
        let total = totalSquares
        guard total > 0 else { return (0, 0) }
        
        let sqrt = Double(total).squareRoot()
        let columns = Int(ceil(sqrt))
        let rows = Int(ceil(Double(total) / Double(columns)))
        
        return (rows, columns)
    }
    
    private func initializeCells() {
        let totalSum = goals.reduce(0) { $0 + (Int($1.totalNumber) ?? 0) }
        let scale = calculateScale(for: totalSum)
        
        // Если общая сумма превышает 10000, обновляем масштаб для всех целей
        if totalSum > 10000 {
            for (index, goal) in goals.enumerated() {
                goals[index].scale = scale
            }
        }
        
        // Теперь используем scaledSquares для определения общего количества ячеек
        let total = goals.reduce(0) { $0 + $1.scaledSquares }
        
        // Сохраняем текущие закрашенные клетки
        let existingColoredCells = cells.filter { $0.isColored }
        
        // Создаем новую сетку
        cells = Array(0..<total).map { position in
            // Проверяем, была ли эта клетка закрашена раньше
            if existingColoredCells.contains(where: { $0.position == position }) {
                return Cell(isColored: true, position: position)
            }
            return Cell(isColored: false, position: position)
        }
        
        coloredCount = cells.filter { $0.isColored }.count
    }
    
    private func colorRandomCells(count: Int, goalId: UUID, markAsCompleted: Bool = false) {
        if let goal = goals.first(where: { $0.id == goalId }) {
            // Получаем все незакрашенные клетки на всем изображении
        var availablePositions = cells.enumerated()
            .filter { !$0.element.isColored }
            .map { $0.offset }
        
            // Рассчитываем, сколько клеток нужно закрасить
            let totalAmount = Double(Int(goal.totalNumber) ?? 0)
            let proportion = Double(count) / totalAmount
            let cellsToColor = Int(ceil(Double(goal.scaledSquares) * proportion))
            
            // Закрашиваем клетки случайным образом по всему изображению
            for _ in 0..<min(cellsToColor, availablePositions.count) {
            guard let randomIndex = availablePositions.indices.randomElement() else { break }
            let position = availablePositions.remove(at: randomIndex)
            cells[position].isColored = true
            coloredCount += 1
        }
        
            // Обновляем отображение
            showGrid = false
            showGrid = true
        }
    }
    
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(savedProjects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
            UserDefaults.standard.synchronize() // Принудительно сохраняем
        }
    }
    
    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "savedProjects"),
           let decoded = try? JSONDecoder().decode([SavedProject].self, from: data) {
            savedProjects = decoded
        }
    }
    
    private func convertImageToData(_ image: Image?) -> Data? {
        guard let image = image else { return nil }
        
        // Получаем UIImage напрямую из PhotosPicker
        if let uiImage = image.asUIImage() {
            // Сохраняем в максимальном качестве
            return uiImage.jpegData(compressionQuality: 1.0)
        }
        
        return nil
    }
    
    private func saveProject() {
        guard let uiImage = originalUIImage else { return }
        
        let projectTitle = projectName.isEmpty ? goals.first?.text ?? "Untitled" : projectName
        let imageData = uiImage.jpegData(compressionQuality: 1.0)!
        
        var existingProjects: [SavedProject] = []
        if let data = UserDefaults.standard.data(forKey: "savedProjects"),
           let decoded = try? JSONDecoder().decode([SavedProject].self, from: data) {
            existingProjects = decoded
        }
        
        if let currentId = currentProjectId,
           let existingIndex = existingProjects.firstIndex(where: { $0.id == currentId }) {
            let updatedProject = SavedProject(
                id: currentId,
                imageData: imageData,
                thumbnailData: createThumbnail(from: uiImage) ?? imageData,
                goals: goals,
                projectName: projectTitle,
                cells: cells,
                showGrid: showGrid,
                deadline: selectedDeadline  // Добавляем дедлайн
            )
            existingProjects[existingIndex] = updatedProject
        } else {
            let newId = UUID()
            let newProject = SavedProject(
                id: newId,
                imageData: imageData,
                thumbnailData: createThumbnail(from: uiImage) ?? imageData,
                goals: goals,
                projectName: projectTitle,
                cells: cells,
                showGrid: showGrid,
                deadline: selectedDeadline  // Добавляем дедлайн
            )
            existingProjects.append(newProject)
            currentProjectId = newId
        }
        
        if let encoded = try? JSONEncoder().encode(existingProjects) {
            UserDefaults.standard.set(encoded, forKey: "savedProjects")
            UserDefaults.standard.synchronize()
            savedProjects = existingProjects
        }
        
        showingSecondView = true
    }
    
    private func getImage(from data: Data) -> Image {
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo") // Возвращаем placeholder вместо nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customDarkNavy
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: selectedImage == nil ? 20 : 10) {
                        if selectedImage == nil {
                            Spacer()
                                .frame(height: 50)  // Добавляем отступ сверху для главного экрана
                            // Кнопка Calendar
                            Button(action: {
                                showingCalendar = true
                            }) {
                                VStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 30))
                                        .foregroundColor(.customBeige)
                                    
                                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.customBeige)
                                }
                                .frame(width: 160, height: 100)
                                .background(Color.customNavy)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.bottom, 20)
                            
                            // Кнопка New Goal (бывшая Upload Image)
                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images
                            ) {
                                VStack {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.customBeige)
                                    
                                    Text("New Goal")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.customBeige)
                                }
                                .frame(width: 160, height: 100)
                                .background(Color.customNavy)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .padding(.bottom, 20)
                            
                            // Новая кнопка My Goals
                            Button(action: {
                                showingSecondView = true
                            }) {
                                VStack {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 30))
                                        .foregroundColor(.customBeige)
                                    
                                    Text("My Goals")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.customBeige)
                                }
                                .frame(width: 160, height: 100)
                                .background(Color.customNavy)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
                                )
                            }
                        } else {
                            Spacer()
                                .frame(height: 20)  // Добавляем отступ сверху для экрана с изображением
                        HStack(spacing: 20) {
                            Button(action: {
                                saveProject()
                            }) {
                                Text("Save")
                                    .fontWeight(.bold)
                                    .foregroundColor(.customDarkNavy)
                                    .frame(width: UIScreen.main.bounds.width * 0.25, height: 40)
                                    .background(Color.customBeige)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showDatePicker = true
                            }) {
                                Text(selectedDeadline == nil ? "Date" : "\(daysRemaining)")
                                    .fontWeight(.bold)
                                    .foregroundColor(.customDarkNavy)
                                    .frame(width: UIScreen.main.bounds.width * 0.25, height: 40)
                                    .background(Color.customBeige)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                self.selectedImage = nil
                                selectedItem = nil
                                goals.removeAll()
                                showGrid = false
                                cells.removeAll()
                                coloredCount = 0
                                clearInputs()
                                projectName = ""  // Очищаем имя проекта
                                selectedDeadline = nil  // Очищаем дедлайн
                            }) {
                                Text("Close")
                                    .fontWeight(.bold)
                                    .foregroundColor(.customBeige)
                                    .frame(width: UIScreen.main.bounds.width * 0.25, height: 40)
                                    .background(Color.customNavy)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.customBeige.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.vertical, 5)
                        
                        // Добавим DatePicker
                        if showDatePicker {
                            VStack {
                                DatePicker("Deadline", selection: Binding(
                                    get: { selectedDeadline ?? Date() },
                                    set: { selectedDeadline = $0 }
                                ), in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(Color.customNavy)
                                .cornerRadius(12)
                                
                                HStack {
                                    Button("Cancel") {
                                        showDatePicker = false
                                    }
                                    .foregroundColor(.customBeige)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.customNavy)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.customBeige.opacity(0.3), lineWidth: 1)
                                    )
                                    
                                    Button("Confirm") {
                                        showDatePicker = false
                                    }
                                    .foregroundColor(.customDarkNavy)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.customBeige)
                                    .cornerRadius(12)
                                }
                                .padding(.bottom)
                            }
                            .transition(.opacity)
                        }
                        
                            // Поле для имени проекта
                        TextField("Project name", text: $projectName)
                            .textFieldStyle(CustomTextFieldStyle())
                            .padding(.horizontal)
                            .padding(.vertical, 5)
                            .multilineTextAlignment(.center)
                        
                            if showGrid {
                                ZStack {
                                    GeometryReader { geometry in
                                        let imageSize = geometry.size.width // Используем квадратный размер
                                        
                                        ZStack {
                                            // Основное изображение
                                            selectedImage!
                                            .resizable()
                                                .aspectRatio(contentMode: .fill) // Возвращаем .fill
                                                .frame(width: imageSize, height: imageSize)
                                            .clipped()
                                            .grayscale(1.0)
                                    
                                        let dimensions = calculateGridDimensions()
                                            let cellWidth = imageSize / CGFloat(dimensions.columns)
                                            let cellHeight = imageSize / CGFloat(dimensions.rows)
                                        
                                            // Цветные клетки
                                        ForEach(0..<cells.count, id: \.self) { index in
                                            let row = index / dimensions.columns
                                            let col = index % dimensions.columns
                                            if cells[index].isColored {
                                                    selectedImage!
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: imageSize, height: imageSize)
                                                        .clipped()
                                                        .mask(
                                                            Rectangle()
                                                                .frame(width: cellWidth, height: cellHeight)
                                                                .position(
                                                                    x: cellWidth * CGFloat(col) + cellWidth/2,
                                                                    y: cellHeight * CGFloat(row) + cellHeight/2
                                                                )
                                                        )
                                            }
                                        }
                                        
                                            // Сетка
                                        ForEach(0..<cells.count, id: \.self) { index in
                                            let row = index / dimensions.columns
                                            let col = index % dimensions.columns
                                            if !cells[index].isColored {
                                                Rectangle()
                                                    .stroke(Color.white, lineWidth: 1)
                                                        .frame(width: cellWidth, height: cellHeight)
                                                    .position(
                                                            x: cellWidth * CGFloat(col) + cellWidth/2,
                                                            y: cellHeight * CGFloat(row) + cellHeight/2
                                                        )
                                                }
                                            }
                                        }
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width * 0.95)
                                .frame(height: UIScreen.main.bounds.width * 0.95) // Делаем контейнер квадратным
                            } else {
                                selectedImage!
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: UIScreen.main.bounds.width * 0.95)  // Ограничиваем максимальную ширину
                            }
                            
                            // Информация о целях
                            HStack {
                                Text("Total: \(goals.reduce(0) { $0 + (Int($1.totalNumber) ?? 0) })")
                            Text("Remaining: \(goals.reduce(0) { $0 + (Int($1.remainingNumber) ?? 0) })")
                        }
                            .padding()
                        .background(Color.customNavy)
                        .cornerRadius(12)
                        
                            // Кнопки Add и Divide Image
                            if showGrid {
                                // Кнопка для показа/скрытия действий
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if showActionButtons {
                                            // Если закрываем действия, скрываем и инпуты
                                            showActionButtons = false
                                            showInputs = false
                                            clearInputs()
                                        } else {
                                            showActionButtons = true
                                        }
                                    }
                                }) {
                                    Image(systemName: showActionButtons ? "chevron.down.circle.fill" : "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.customBeige)
                                }
                                .padding(.vertical, 5)
                                
                                if showActionButtons {
                                    HStack(spacing: 20) {
                                        Button(action: {
                                            if isEditing {
                                                updateGoal()
                                                showEditForm = false
                                                showInputs = false
                                            } else if showInputs {
                                                if !inputText.isEmpty && !inputNumber.isEmpty {
                                                    addGoal()
                                                }
                                                showInputs = false
                                                clearInputs()
                                            } else {
                                                showInputs = true
                                                clearInputs()
                                            }
                                        }) {
                                            Text(isEditing ? "Update" : "Add")
                                                .foregroundColor(.customDarkNavy)
                                                .frame(width: 100, height: 35)
                                                .background(Color.customBeige)
                                                .cornerRadius(12)
                                        }
                                        
                                        Button(action: {
                                            showGrid = true
                                            showInputs = false
                                            initializeCells()
                                        }) {
                                            HStack {
                                                Image(systemName: "grid")
                                                    .font(.system(size: 18))
                                                Text("Divide Image")
                                                    .font(.system(size: 15, weight: .medium))
                                            }
                                            .foregroundColor(.customDarkNavy)
                                            .frame(width: 140, height: 35)
                                            .background(Color.customBeige)
                                            .cornerRadius(12)
                                        }
                                    }
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            } else {
                                // Показываем кнопки всегда, когда сетка не отображается
                                HStack(spacing: 20) {
                                    Button(action: {
                                        if isEditing {
                                            updateGoal()
                                            showEditForm = false
                                            showInputs = false
                                        } else if showInputs {
                                            if !inputText.isEmpty && !inputNumber.isEmpty {
                                                addGoal()
                                            }
                                            showInputs = false
                                            clearInputs()
                                        } else {
                                            showInputs = true
                                            clearInputs()
                                        }
                                    }) {
                                        Text(isEditing ? "Update" : "Add")
                                            .foregroundColor(.customDarkNavy)
                                            .frame(width: 100, height: 35)
                                            .background(Color.customBeige)
                                            .cornerRadius(12)
                                    }
                                    
                                    Button(action: {
                                        showGrid = true
                                        showInputs = false
                                        initializeCells()
                                        showActionButtons = false  // Скрываем кнопки при разделении
                                    }) {
                                        HStack {
                                            Image(systemName: "grid")
                                                .font(.system(size: 18))
                                            Text("Divide Image")
                                                .font(.system(size: 15, weight: .medium))
                                        }
                                        .foregroundColor(.customDarkNavy)
                                        .frame(width: 140, height: 35)
                                        .background(Color.customBeige)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            
                            // Форма ввода/редактирования
                            if showInputs || showEditForm {
                                VStack(spacing: 10) {
                                    TextField("Enter text", text: $inputText)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .padding(.horizontal)
                                        .background(Color.customBeige.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.customBeige.opacity(0.3), lineWidth: 1)
                                        )
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button(action: {
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                                                }) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.customAccent)
                                                        .font(.system(size: 20))
                                                }
                                            }
                                        }
                                    
                                    HStack {
                                        TextField("Enter number", text: $inputNumber)
                                            .textFieldStyle(CustomTextFieldStyle())
                                            .keyboardType(.numberPad)
                                            .padding(.horizontal)
                                            .background(Color.customBeige.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.customBeige.opacity(0.3), lineWidth: 1)
                                            )
                                            
                                        Picker("Unit", selection: $selectedUnit) {
                                            Section(header: Text("Количество").foregroundColor(.gray)) {
                                                ForEach([GoalUnit.pieces, .packs, .kilograms, .liters, .meters], id: \.self) { unit in
                                                    Text(unit.rawValue).tag(unit)
                                                }
                                            }
                                            
                                            Section(header: Text("Деньги").foregroundColor(.gray)) {
                                                ForEach([GoalUnit.euro, .dollar, .ruble, .tenge], id: \.self) { unit in
                                                    Text(unit.rawValue).tag(unit)
                                                }
                                            }
                                            
                                            Section(header: Text("Время").foregroundColor(.gray)) {
                                                ForEach([GoalUnit.days, .weeks, .months, .hours], id: \.self) { unit in
                                                    Text(unit.rawValue).tag(unit)
                                                }
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 80)
                                        .background(Color.customBeige)
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                                .transition(.opacity)
                            }
                            
                            // Пикер целей и кнопки управления
                            HStack {
                                // Красный крестик всегда виден
                                Button(action: {
                                    if selectedGoalIndex >= goals.count { return }
                                    withAnimation {
                                        goals.remove(at: selectedGoalIndex)
                                        if selectedGoalIndex >= goals.count {
                                            selectedGoalIndex = max(goals.count - 1, 0)
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 20))
                            }
                            
                            Picker("Goals", selection: $selectedGoalIndex) {
                                ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                                        HStack(spacing: 4) {
                                        Text("\(goal.text)")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                            .strikethrough(goal.isCompleted)
                                                .lineLimit(1)
                                            
                                        Text(goal.progress)
                                            .font(.system(size: 15, weight: .regular))
                                                .foregroundColor(.customAccent)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .multilineTextAlignment(.center)
                                        .tag(index)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .overlay(
                                    Button(action: {
                                        showGoalsList = true
                                    }) {
                                        Color.clear
                                            .frame(width: UIScreen.main.bounds.width * 0.5)
                                    }
                                )
                                
                                // Карандаш всегда виден
                                if let goal = goals[safe: selectedGoalIndex] {
                                    Button(action: {
                                        startEditing(goal)
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .foregroundColor(.customAccent)
                                            .font(.system(size: 20))
                                    }
                                }
                                
                                // Зеленая галочка видна только после разделения фото
                                if let selectedGoal = goals[safe: selectedGoalIndex],
                                   !selectedGoal.isCompleted && showGrid {
                                    Button(action: {
                                        if let remainingAmount = Int(selectedGoal.remainingNumber) {
                                            updateGoalProgress(goalId: selectedGoal.id, amount: remainingAmount)
                                        }
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 20))
                                    }
                                }
                            }
                            .frame(height: UIScreen.main.bounds.height * 0.08)
                            .background(Color.customNavy)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .alert(isPresented: $showAlert) {
                                Alert(
                                    title: Text("Image Not Divided"),
                                    message: Text("Please divide the image first by clicking 'Divide Image' button."),
                                    dismissButton: .default(Text("OK"))
                                )
                            }
                            
                            // Поле частичного выполнения
                            if let selectedGoal = goals[safe: selectedGoalIndex],
                               !selectedGoal.isCompleted && showGrid {
                                HStack(spacing: 15) {
                                    TextField("Enter completed amount", text: $partialCompletion)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .keyboardType(.numberPad)
                                        .padding(.horizontal)
                                        .frame(width: UIScreen.main.bounds.width * 0.35)
                                        .background(Color.customBeige.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.customBeige.opacity(0.3), lineWidth: 1)
                                        )
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button(action: {
                                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                                                }) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.customAccent)
                                                        .font(.system(size: 20))
                                                }
                                            }
                                        }
                                    
                                    Button("Complete") {
                                        if let partialAmount = Int(partialCompletion),
                                           let selectedGoal = goals[safe: selectedGoalIndex] {
                                            // Сохраняем текущее состояние перед изменением
                                            lastCellsState = cells
                                            lastGoalsState = goals
                                            
                                            updateGoalProgress(goalId: selectedGoal.id, amount: partialAmount)
                                            partialCompletion = ""
                                        }
                                    }
                                    .foregroundColor(.customDarkNavy)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.customBeige)
                                    .cornerRadius(12)
                                    
                                    // Добавляем кнопку Undo
                                    if lastCellsState != nil {
                                        Button(action: {
                                            // Восстанавливаем предыдущее состояние
                                            if let lastCells = lastCellsState,
                                               let lastGoals = lastGoalsState {
                                                withAnimation {
                                                    cells = lastCells
                                                    goals = lastGoals
                                                    lastCellsState = nil
                                                    lastGoalsState = nil
                                                }
                                            }
                                        }) {
                                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                                .foregroundColor(.customAccent)
                                                .font(.system(size: 24))
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .onChange(of: selectedImage) { _ in
                    // Принудительно обновляем layout при изменении изображения
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            isLayoutReady = true
                        }
                    }
                }
                .onAppear {
                    loadFromStorage()
                    // Принудительно обновляем layout при появлении экрана
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            isLayoutReady = true
                        }
                    }
                }
                .id(isLayoutReady) // Принудительно пересоздаем view при изменении isLayoutReady
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingSecondView) {
            SecondView(
                savedProjects: $savedProjects,
                selectedImage: $selectedImage,
                goals: $goals,
                isPresented: $showingSecondView,
                cells: $cells,
                showGrid: $showGrid,
                currentProjectId: $currentProjectId,
                projectName: $projectName,
                originalUIImage: $originalUIImage,
                selectedDeadline: $selectedDeadline
            )
        }
        .sheet(isPresented: $showGoalsList) {
            NavigationView {
                List {
                    ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                        HStack {
                            Button(action: {
                                selectedGoalIndex = index
                                showGoalsList = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(goal.text)
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(.white)
                                            .strikethrough(goal.isCompleted)
                                        
                                        Text(goal.progress)
                                            .font(.system(size: 15))
                                            .foregroundColor(.customAccent)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            if !goal.isCompleted {
                                Button(action: {
                                    if showGrid {
                                        withAnimation {
                                            if let remainingAmount = Int(goal.remainingNumber),
                                               let goalIndex = goals.firstIndex(where: { $0.id == goal.id }) {
                                                goals[goalIndex].remainingNumber = "0"
                                                goals[goalIndex].isCompleted = true
                                                
                                                colorRandomCells(count: remainingAmount, 
                                                               goalId: goal.id, 
                                                               markAsCompleted: true)
                                            }
                                        }
                                    } else {
                                        showAlert = true
                                    }
                                }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(showGrid ? .green : .green.opacity(0.3))
                                        .font(.system(size: 20))
                                }
                                .disabled(!showGrid)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 20))
                            }
                        }
                        .listRowBackground(Color.customNavy)
                    }
                }
                .listStyle(.plain)
                .background(Color.customDarkNavy)
                .navigationTitle("Goals")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showGoalsList = false
                        }
                        .foregroundColor(.white)
                    }
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Image Not Divided"),
                        message: Text("Please divide the image first by clicking 'Divide Image' button."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarView(
                savedProjects: $savedProjects,
                selectedImage: $selectedImage,
                goals: $goals,
                cells: $cells,
                showGrid: $showGrid
            )
        }
        .onChange(of: selectedItem) { newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Очищаем предыдущее состояние
                    goals.removeAll()
                    cells.removeAll()
                    currentProjectId = nil  // Важно!
                    projectName = ""  // Очищаем имя проекта
                    selectedDeadline = nil  // Очищаем дедлайн
                    
                    // Устанавливаем новое изображение
                    originalUIImage = uiImage
                    selectedImage = Image(uiImage: uiImage)
                }
            }
        }
    }
    
    private func addGoal() {
        // Проверяем валидность ввода
        guard !inputText.isEmpty else { return }
        guard !inputNumber.isEmpty else { return }
        guard let number = Int(inputNumber), number > 0 else { return }
        
        let scale = calculateScale(for: number)
        
        withAnimation {
            goals.append(Goal(
                text: inputText,
                totalNumber: inputNumber,
                remainingNumber: inputNumber,
                unit: selectedUnit,
                scale: scale
            ))
        }
        
        // Очищаем поля ввода
        clearInputs()
        
        // Если сетка уже отображается, обновляем её
        if showGrid {
            initializeCells()
        }
    }
    
    private func startEditing(_ goal: Goal) {
        editingGoal = goal
        inputText = goal.text
        inputNumber = goal.totalNumber
        selectedUnit = goal.unit
        isEditing = true
        showEditForm = true
    }
    
    private func updateGoal() {
        if let editingGoal = editingGoal,
           let index = goals.firstIndex(where: { $0.id == editingGoal.id }) {
            goals[index] = Goal(
                id: editingGoal.id, // Сохраняем тот же id
                text: inputText,
                totalNumber: inputNumber,
                remainingNumber: inputNumber,
                unit: selectedUnit,
                scale: editingGoal.scale
            )
            clearInputs()
            isEditing = false
            self.editingGoal = nil
        }
    }
    
    private func clearInputs() {
        inputText = ""
        inputNumber = ""
    }
    
    private func getCellsForGoal(_ goal: Goal) -> Int {
        return goal.scaledSquares
    }
    
    // Добавим новую функцию для восстановления состояния сетки
    private func restoreGridState(from project: SavedProject) {
        if let uiImage = UIImage(data: project.imageData) {
            originalUIImage = uiImage
            selectedImage = Image(uiImage: uiImage)
            goals = project.goals
            cells = project.cells
            showGrid = project.showGrid
            projectName = project.projectName
            currentProjectId = project.id
            selectedDeadline = project.deadline  // Восстанавливаем дедлайн
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isLayoutReady = true
                }
            }
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://familykorotkey.github.io/splitup-privacy-policy/") {
            UIApplication.shared.open(url)
        }
    }
    
    // Функция для автоматического определения масштаба
    private func calculateScale(for number: Int) -> Int {
        if number <= 10000 { return 1 }
        else if number <= 100000 { return 10 }
        else if number <= 1000000 { return 100 }
        else if number <= 10000000 { return 1000 }
        else { return 10000 }
    }
    
    private func updateGoalProgress(goalId: UUID, amount: Int) {
        if let goalIndex = goals.firstIndex(where: { $0.id == goalId }),
           let remainingAmount = Int(goals[goalIndex].remainingNumber),
           amount <= remainingAmount {
            
            // Обновляем состояние цели
            let newRemaining = remainingAmount - amount
            goals[goalIndex].remainingNumber = String(newRemaining)
            goals[goalIndex].isCompleted = newRemaining == 0
            
            // Закрашиваем клетки в соответствии с введенным числом
            let scale = goals[goalIndex].scale
            let cellsToColor = Int(ceil(Double(amount) / Double(scale)))
            
            // Получаем только незакрашенные клетки
            var availablePositions = cells.enumerated()
                .filter { !$0.element.isColored }
                .map { $0.offset }
            
            // Закрашиваем точное количество клеток
            for _ in 0..<cellsToColor {
                guard let randomIndex = availablePositions.indices.randomElement() else { break }
                let position = availablePositions.remove(at: randomIndex)
                cells[position].isColored = true
            }
            
            // Обновляем общий счетчик закрашенных клеток
            coloredCount = cells.filter { $0.isColored }.count
            
            // Обновляем отображение
            withAnimation {
                showGrid = false
                showGrid = true
            }
        }
    }
    
    // Добавляем функцию создания миниатюры
    private func createThumbnail(from image: UIImage) -> Data? {
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumbnail?.jpegData(compressionQuality: 0.7)
    }
    
    // Добавим вычисляемое свойство для отображения оставшихся дней
    private var daysRemaining: String {
        guard let deadline = selectedDeadline else { return "Date" }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        guard let days = components.day else { return "Date" }
        if days == 0 {
            return "Today"
        } else if days == 1 {
            return "1 day"
        } else {
            return "\(days) days"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
            ContentView()
            .previewDevice("iPhone 14")  // Указываем конкретное устройство
            .previewDisplayName("iPhone 14")  // Добавляем название в превью
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Добавим расширение для конвертации Image в UIImage
extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView:
            self
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 300, height: 300)  // Уменьшаем размер до 300x300
        )
        
        let view = controller.view
        let targetSize = CGSize(width: 300, height: 300)  // Уменьшаем целевой размер
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view?.bounds ?? .zero, afterScreenUpdates: true)
        }
    }
}

