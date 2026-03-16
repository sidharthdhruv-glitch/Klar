import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var rules: [Rule]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddRule = false
    @State private var showAddCategory = false
    @State private var includeChartsInExport = true
    @State private var autoExportOnFirst = false
    @State private var exportFormat = "PDF"
    @State private var userName = "Sid"
    @State private var userEmail = "sid@example.com"
    @State private var showDeleteConfirmation = false
    @State private var categoryToDelete: Category?

    @State private var mockRules: [(String, String)] = [
        ("zomato", "Food"),
        ("swiggy", "Food"),
        ("uber", "Transport"),
        ("netflix", "Entertainment"),
        ("spotify", "Entertainment"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("SETTINGS")
                    .font(KlarFonts.display(28))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Rule Engine
                ruleEngineSection

                // Custom Categories
                customCategoriesSection

                // Export Settings
                exportSection

                // Profile
                profileSection

                Spacer(minLength: 100)
            }
        }
        .background(KlarColors.background)
        .sheet(isPresented: $showAddRule) {
            AddRuleSheet { keyword, category in
                mockRules.append((keyword, category))
                showAddRule = false
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet {
                showAddCategory = false
            }
        }
    }

    // MARK: - Rule Engine
    private var ruleEngineSection: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "RULE ENGINE")

                ForEach(Array(mockRules.enumerated()), id: \.offset) { index, rule in
                    HStack {
                        Text("If")
                            .font(KlarFonts.body(14))
                            .foregroundStyle(KlarColors.secondary)
                        Text("\"\(rule.0)\"")
                            .font(KlarFonts.body(14))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text("→")
                            .foregroundStyle(KlarColors.secondary)
                        CategoryPill(
                            name: rule.1,
                            color: KlarColors.categoryColor(for: rule.1)
                        )
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            mockRules.remove(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button {
                    showAddRule = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Rule")
                    }
                    .font(KlarFonts.label(13))
                    .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Custom Categories
    private var customCategoriesSection: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "CUSTOM CATEGORIES")

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ForEach(MockData.categories, id: \.name) { cat in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: cat.colorHex).opacity(0.2))
                                .frame(height: 44)
                                .overlay(
                                    Image(systemName: cat.sfSymbol)
                                        .foregroundStyle(Color(hex: cat.colorHex))
                                )

                            Text(cat.name.uppercased())
                                .font(KlarFonts.label(9))
                                .tracking(0.5)
                                .foregroundStyle(KlarColors.secondary)
                        }
                    }

                    // Add button
                    Button {
                        showAddCategory = true
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(KlarColors.inactive, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .frame(height: 44)
                                .overlay(
                                    Image(systemName: "plus")
                                        .foregroundStyle(KlarColors.secondary)
                                )

                            Text("ADD NEW")
                                .font(KlarFonts.label(9))
                                .tracking(0.5)
                                .foregroundStyle(KlarColors.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Export
    private var exportSection: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "EXPORT SETTINGS")

                Toggle(isOn: $includeChartsInExport) {
                    Text("Include charts in PDF export")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(.white)
                }
                .tint(KlarColors.positive)

                Toggle(isOn: $autoExportOnFirst) {
                    Text("Auto-export on 1st of month")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(.white)
                }
                .tint(KlarColors.positive)

                HStack {
                    Text("Export format")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("Format", selection: $exportFormat) {
                        Text("PDF").tag("PDF")
                        Text("Excel").tag("Excel")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                Button {
                    // Export action
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Now")
                    }
                    .font(KlarFonts.label(14))
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Profile
    private var profileSection: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "PROFILE")

                HStack(spacing: 14) {
                    // Avatar
                    Circle()
                        .fill(KlarColors.finance)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(String(userName.prefix(1)).uppercased())
                                .font(KlarFonts.heading(20))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Name", text: $userName)
                            .font(KlarFonts.body(15))
                            .foregroundStyle(.white)
                        TextField("Email", text: $userEmail)
                            .font(KlarFonts.label(13))
                            .foregroundStyle(KlarColors.secondary)
                    }
                }

                Divider()
                    .background(KlarColors.barTrack)

                Button(role: .destructive) {
                    // Sign out
                } label: {
                    Text("Sign Out")
                        .font(KlarFonts.label(14))
                        .foregroundStyle(KlarColors.negative)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Add Rule Sheet
struct AddRuleSheet: View {
    let onAdd: (String, String) -> Void
    @State private var keyword = ""
    @State private var selectedCategory = "Food"
    @Environment(\.dismiss) private var dismiss

    let categoryNames = MockData.categories.map(\.name)

    var body: some View {
        VStack(spacing: 20) {
            Text("ADD RULE")
                .font(KlarFonts.heading(18))
                .foregroundStyle(.white)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("KEYWORD")
                    .font(KlarFonts.label(11))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)

                TextField("e.g. zomato, amazon", text: $keyword)
                    .font(KlarFonts.body(14))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(KlarColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CATEGORY")
                    .font(KlarFonts.label(11))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 10) {
                    ForEach(categoryNames, id: \.self) { name in
                        Button {
                            selectedCategory = name
                        } label: {
                            Text(name.uppercased())
                                .font(KlarFonts.label(11))
                                .foregroundStyle(selectedCategory == name ? .white : KlarColors.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(selectedCategory == name ? KlarColors.categoryColor(for: name).opacity(0.3) : KlarColors.surfaceElevated)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            Button {
                guard !keyword.isEmpty else { return }
                onAdd(keyword.lowercased(), selectedCategory)
            } label: {
                Text("Add Rule")
                    .font(KlarFonts.label(14))
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
        .background(KlarColors.background)
        .presentationDetents([.medium])
    }
}

// MARK: - Add Category Sheet
struct AddCategorySheet: View {
    let onDismiss: () -> Void
    @State private var categoryName = ""
    @State private var selectedSymbol = "star.fill"
    @State private var selectedColor = Color.purple
    @Environment(\.dismiss) private var dismiss

    let symbols = ["star.fill", "heart.fill", "house.fill", "car.fill",
                   "airplane", "gift.fill", "book.fill", "music.note",
                   "gamecontroller.fill", "camera.fill", "paintbrush.fill", "leaf.fill"]

    var body: some View {
        VStack(spacing: 20) {
            Text("NEW CATEGORY")
                .font(KlarFonts.heading(18))
                .foregroundStyle(.white)
                .padding(.top, 24)

            TextField("Category name", text: $categoryName)
                .font(KlarFonts.body(14))
                .foregroundStyle(.white)
                .padding(14)
                .background(KlarColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 8) {
                Text("ICON")
                    .font(KlarFonts.label(11))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 20))
                                .foregroundStyle(selectedSymbol == symbol ? .white : KlarColors.secondary)
                                .frame(width: 44, height: 44)
                                .background(selectedSymbol == symbol ? selectedColor.opacity(0.3) : KlarColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            ColorPicker("Category Color", selection: $selectedColor)
                .font(KlarFonts.body(14))
                .foregroundStyle(.white)

            Spacer()

            Button {
                dismiss()
                onDismiss()
            } label: {
                Text("Create Category")
                    .font(KlarFonts.label(14))
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
        .background(KlarColors.background)
        .presentationDetents([.large])
    }
}
