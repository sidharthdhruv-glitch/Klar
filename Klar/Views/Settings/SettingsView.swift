import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var rules: [Rule]
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddCategory = false
    @State private var showRuleEngine = false
    @AppStorage("includeChartsInExport") private var includeChartsInExport = true
    @AppStorage("autoExportOnFirst") private var autoExportOnFirst = false
    @AppStorage("exportFormat") private var exportFormat = "PDF"
    @AppStorage("userName") private var userName = "User"
    @AppStorage("userEmail") private var userEmail = ""
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 50000
    @FocusState private var isBudgetFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("SETTINGS")
                    .font(KlarFonts.display(28))
                    .foregroundStyle(KlarColors.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ruleEngineSection
                customCategoriesSection
                budgetSection
                exportSection
                profileSection

                Spacer(minLength: 20)
            }
        }
        .background(KlarColors.background)
        .sheet(isPresented: $showRuleEngine) {
            RuleEngineSheet()
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet { name, colorHex, symbol in
                let cat = Category(name: name, colorHex: colorHex, sfSymbol: symbol)
                modelContext.insert(cat)
                try? modelContext.save()
                showAddCategory = false
            }
        }
    }

    // MARK: - Rule Engine
    private var ruleEngineSection: some View {
        Button {
            showRuleEngine = true
        } label: {
            KlarCard(dashedBorder: true) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: "RULE ENGINE")
                        Text("\(rules.count) rule\(rules.count == 1 ? "" : "s") configured")
                            .font(KlarFonts.label(11))
                            .foregroundStyle(KlarColors.inactive)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KlarColors.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Custom Categories
    private var customCategoriesSection: some View {
        KlarCard(dashedBorder: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "CATEGORIES")

                let displayCategories = categories.isEmpty ? DefaultData.categories : Array(categories)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ForEach(displayCategories, id: \.name) { cat in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: cat.colorHex).opacity(0.15))
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

    // MARK: - Budget
    private var budgetSection: some View {
        KlarCard(dashedBorder: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "MONTHLY BUDGET")

                HStack {
                    Text("₹")
                        .font(KlarFonts.heading(20))
                        .foregroundStyle(KlarColors.primary)
                    TextField("50000", value: $monthlyBudget, format: .number)
                        .font(KlarFonts.heading(20))
                        .foregroundStyle(KlarColors.primary)
                        .keyboardType(.numberPad)
                        .focused($isBudgetFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isBudgetFocused = false
                                }
                                .fontWeight(.semibold)
                            }
                        }
                }
                .padding(14)
                .background(KlarColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("This is used to calculate your burn rate on the dashboard.")
                    .font(KlarFonts.label(11))
                    .foregroundStyle(KlarColors.inactive)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Export
    private var exportSection: some View {
        KlarCard(dashedBorder: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "EXPORT SETTINGS")

                Toggle(isOn: $includeChartsInExport) {
                    Text("Include charts in PDF export")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(KlarColors.primary)
                }
                .tint(KlarColors.positive)

                Toggle(isOn: $autoExportOnFirst) {
                    Text("Auto-export on 1st of month")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(KlarColors.primary)
                }
                .tint(KlarColors.positive)

                HStack {
                    Text("Export format")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(KlarColors.primary)
                    Spacer()
                    Picker("Format", selection: $exportFormat) {
                        Text("PDF").tag("PDF")
                        Text("Excel").tag("Excel")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                Button {
                    // Export action placeholder
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Now")
                    }
                    .font(KlarFonts.label(14))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(KlarColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Profile
    private var profileSection: some View {
        KlarCard(dashedBorder: true) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "PROFILE")

                HStack(spacing: 14) {
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
                            .foregroundStyle(KlarColors.primary)
                        TextField("Email", text: $userEmail)
                            .font(KlarFonts.label(13))
                            .foregroundStyle(KlarColors.secondary)
                    }
                }

                Divider()
                    .background(KlarColors.barTrack)

                Button(role: .destructive) {
                    // Sign out placeholder
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

// MARK: - Rule Engine Sheet
struct RuleEngineSheet: View {
    @Query private var rules: [Rule]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showAddRule = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlarColors.secondary)
                }

                Spacer()

                Text("RULE ENGINE")
                    .font(KlarFonts.heading(18))
                    .foregroundStyle(KlarColors.primary)

                Spacer()

                Button { showAddRule = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlarColors.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Text("Rules auto-categorize imported transactions by keyword matching.")
                .font(KlarFonts.label(11))
                .foregroundStyle(KlarColors.inactive)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Divider().background(KlarColors.barTrack)

            if rules.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(KlarColors.inactive)
                    Text("No rules yet")
                        .font(KlarFonts.heading(16))
                        .foregroundStyle(KlarColors.secondary)
                    Text("Add rules to auto-categorize your imports.")
                        .font(KlarFonts.label(12))
                        .foregroundStyle(KlarColors.inactive)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(rules, id: \.id) { rule in
                            HStack(spacing: 10) {
                                Text("If")
                                    .font(KlarFonts.body(14))
                                    .foregroundStyle(KlarColors.secondary)
                                Text("\"\(rule.keyword)\"")
                                    .font(KlarFonts.body(14))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(KlarColors.primary)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(KlarColors.secondary)
                                CategoryPill(
                                    name: rule.targetCategory,
                                    color: KlarColors.categoryColor(for: rule.targetCategory)
                                )
                                Spacer()
                                Button {
                                    modelContext.delete(rule)
                                    try? modelContext.save()
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                        .foregroundStyle(KlarColors.negative.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)

                            Divider()
                                .background(KlarColors.barTrack)
                                .padding(.leading, 20)
                        }
                    }
                }
            }

            // Add rule button at bottom
            Button {
                showAddRule = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Rule")
                }
                .font(KlarFonts.label(14))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(KlarColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(KlarColors.background)
        .presentationDetents([.large])
        .sheet(isPresented: $showAddRule) {
            AddRuleSheet { keyword, category in
                let rule = Rule(keyword: keyword, targetCategory: category)
                modelContext.insert(rule)
                try? modelContext.save()
                showAddRule = false
            }
        }
    }
}

// MARK: - Add Rule Sheet
struct AddRuleSheet: View {
    let onAdd: (String, String) -> Void
    @State private var keyword = ""
    @State private var selectedCategory = "Food"
    @Environment(\.dismiss) private var dismiss

    let categoryNames = ["Food", "Transport", "Shopping", "Entertainment", "Health", "Utilities", "Finance", "Misc", "Income"]

    var body: some View {
        VStack(spacing: 20) {
            Text("ADD RULE")
                .font(KlarFonts.heading(18))
                .foregroundStyle(KlarColors.primary)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("KEYWORD")
                    .font(KlarFonts.label(11))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)

                TextField("e.g. zomato, amazon", text: $keyword)
                    .font(KlarFonts.body(14))
                    .foregroundStyle(KlarColors.primary)
                    .padding(14)
                    .background(KlarColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("When a transaction description contains this keyword, it will be assigned the selected category.")
                    .font(KlarFonts.label(11))
                    .foregroundStyle(KlarColors.inactive)
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
                                .background(selectedCategory == name ? KlarColors.categoryColor(for: name) : KlarColors.surfaceElevated)
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
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KlarColors.primary)
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
    let onAdd: (String, String, String) -> Void
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
                .foregroundStyle(KlarColors.primary)
                .padding(.top, 24)

            TextField("Category name", text: $categoryName)
                .font(KlarFonts.body(14))
                .foregroundStyle(KlarColors.primary)
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
                .foregroundStyle(KlarColors.primary)

            Spacer()

            Button {
                guard !categoryName.isEmpty else { return }
                let hex = selectedColor.toHex()
                onAdd(categoryName, hex, selectedSymbol)
                dismiss()
            } label: {
                Text("Create Category")
                    .font(KlarFonts.label(14))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KlarColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
        .background(KlarColors.background)
        .presentationDetents([.large])
    }
}
