import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [Rule]
    @Query(sort: \Transaction.date, order: .reverse) private var existingTransactions: [Transaction]

    @Query private var accounts: [Account]

    @State private var accountName = ""
    @State private var selectedAccountType: AccountType = .savings
    @State private var uploads: [UploadEntry] = []
    @State private var showDocumentPicker = false
    @State private var isDragTargeted = false
    @State private var showConflictResolver = false
    @State private var conflictPairs: [(new: StatementParser.ParsedRow, existing: Transaction)] = []
    @State private var pendingTransactions: [StatementParser.ParsedRow] = []
    @State private var showParseError = false
    @State private var parseErrorMessage = ""
    @State private var currentParsingAccount = ""
    @State private var currentImportSource: ImportSource = .csv
    @State private var dropZoneIconOffset: CGFloat = 0
    @State private var dropZonePulsing = false

    // Excel/CSV import states
    @State private var showExcelPicker = false
    @State private var excelImportWarnings: [String] = []
    @State private var showImportWarnings = false
    @State private var importSkippedRows = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Text("IMPORT ")
                            .font(KlarFonts.display(32))
                            .foregroundStyle(KlarColors.primary)
                        Text("HUB")
                            .font(KlarFonts.serifItalic(32))
                            .foregroundStyle(KlarColors.secondary)
                    }

                    Text("UPLOAD FILES")
                        .font(KlarFonts.cardTitle())
                        .tracking(1.5)
                        .foregroundStyle(KlarColors.primary)

                    Text("Upload csv, xlsx, pdf, or photo of receipt.\nParsed transactions go to your inbox for\nreview before being added.")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(KlarColors.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                // Drop Zone (Task 20: animated)
                dropZone
                    .padding(.horizontal, 20)
                    .staggeredAppearance(index: 0)

                // Excel/CSV Import Button
                excelImportButton
                    .padding(.horizontal, 20)

                // Account Name Field with SlidingPicker (Task 24)
                KlarCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(KlarColors.secondary)
                            Text("ACCOUNT NAME")
                                .font(KlarFonts.cardTitle())
                                .tracking(1.5)
                                .foregroundStyle(KlarColors.primary)
                        }

                        TextField("e.g. HDFC Savings, ICICI Credit Card", text: $accountName)
                            .font(KlarFonts.body(14))
                            .foregroundStyle(KlarColors.primary)
                            .padding(14)
                            .background(KlarColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        // SlidingPicker replaces old segmented picker
                        SlidingPicker(selection: $selectedAccountType)

                        Text("Labels where each transaction came from.")
                            .font(KlarFonts.label(11))
                            .foregroundStyle(KlarColors.secondary)
                    }
                }
                .pressableCard()
                .padding(.horizontal, 20)
                .staggeredAppearance(index: 1)

                // Uploads Section
                if !uploads.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "UPLOADS")
                            .padding(.horizontal, 20)

                        VStack(spacing: 1) {
                            ForEach(uploads) { entry in
                                uploadRow(entry)
                            }
                        }
                    }
                    .staggeredAppearance(index: 2)
                }

                // Pending transactions review
                if !pendingTransactions.isEmpty {
                    pendingReviewSection
                        .staggeredAppearance(index: 3)
                }

                Spacer(minLength: 20)
            }
        }
        .background(KlarColors.background)
        .sheet(isPresented: $showConflictResolver) {
            ConflictResolverView(
                conflicts: $conflictPairs,
                onResolve: { resolved in
                    handleResolvedConflicts(resolved)
                }
            )
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .commaSeparatedText],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .fileImporter(
            isPresented: $showExcelPicker,
            allowedContentTypes: ImportService.supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            handleExcelImport(result)
        }
        .alert("Import Warnings", isPresented: $showImportWarnings) {
            Button("OK") {}
        } message: {
            Text(excelImportWarnings.joined(separator: "\n")
                + (importSkippedRows > 0 ? "\n\(importSkippedRows) rows skipped." : ""))
        }
        .alert("Parse Error", isPresented: $showParseError) {
            Button("OK") {}
        } message: {
            Text(parseErrorMessage)
        }
        .onAppear {
            startDropZoneAnimation()
        }
    }

    // MARK: - Animated Drop Zone (Task 20)
    private var dropZone: some View {
        Button {
            showDocumentPicker = true
            HapticManager.medium()
        } label: {
            VStack(spacing: 14) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 36))
                    .foregroundStyle(KlarColors.primary)
                    .offset(y: dropZoneIconOffset)

                Text("DROP YOUR FILES HERE OR BROWSE")
                    .font(KlarFonts.label(13))
                    .tracking(1)
                    .foregroundStyle(KlarColors.primary)

                Text("MAX FILE SIZE UPTO 100MB")
                    .font(KlarFonts.label(10))
                    .tracking(0.5)
                    .foregroundStyle(KlarColors.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDragTargeted ? KlarColors.dropZone.opacity(0.6) : KlarColors.dropZone.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        KlarColors.border,
                        lineWidth: dropZonePulsing ? 2.5 : 1.5
                    )
                    .opacity(dropZonePulsing ? 0.8 : 0.5)
            )
        }
        .dropDestination(for: Data.self) { items, location in
            HapticManager.success()
            return true
        } isTargeted: { targeted in
            isDragTargeted = targeted
            if targeted { HapticManager.light() }
        }
    }

    private func startDropZoneAnimation() {
        // Floating icon animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            dropZoneIconOffset = -6
        }
        // Pulsing border
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            dropZonePulsing = true
        }
    }

    // MARK: - Upload Row
    private func uploadRow(_ entry: UploadEntry) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(uploadBadgeColor(entry.fileType).opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(entry.fileType)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(uploadBadgeColor(entry.fileType))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(KlarFonts.body(14))
                    .foregroundStyle(KlarColors.primary)
                    .lineLimit(1)

                Text(entry.statusMessage)
                    .font(KlarFonts.label(11))
                    .foregroundStyle(KlarColors.secondary)
            }

            Spacer()

            StatusBadge(status: entry.status)

            Button {
                uploads.removeAll { $0.id == entry.id }
                HapticManager.light()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(KlarColors.secondary)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(KlarColors.surface)
    }

    // MARK: - Pending Review Section
    private var pendingReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "PARSED TRANSACTIONS (\(pendingTransactions.count))")
                Spacer()
                Button {
                    addAllPendingTransactions()
                    HapticManager.success()
                } label: {
                    Text("ADD ALL")
                        .font(KlarFonts.label(12))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(KlarColors.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)

            ForEach(Array(pendingTransactions.enumerated()), id: \.offset) { index, row in
                pendingRow(row, index: index)
            }
        }
    }

    private func pendingRow(_ row: StatementParser.ParsedRow, index: Int) -> some View {
        let merchant = AutoCategorizer.extractMerchant(from: row.description)
        let category = AutoCategorizer.categorize(description: row.description, rules: Array(rules))
        let catColor = KlarColors.categoryColor(for: category)

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(catColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: categorySymbol(for: category))
                        .font(.system(size: 14))
                        .foregroundStyle(catColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(merchant.uppercased())
                    .font(KlarFonts.label(13))
                    .fontWeight(.bold)
                    .foregroundStyle(KlarColors.primary)

                HStack(spacing: 6) {
                    CategoryPill(name: category, color: catColor)
                    Text(formatDate(row.date))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(KlarColors.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(row.type == .income
                    ? CurrencyHelper.formatSigned(row.amount)
                    : CurrencyHelper.formatSigned(-row.amount))
                    .font(KlarFonts.label(14))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(row.type == .income ? KlarColors.positive : KlarColors.negative)

                HStack(spacing: 4) {
                    Button {
                        addSingleTransaction(row, at: index)
                        HapticManager.success()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KlarColors.positive)
                    }
                    Button {
                        pendingTransactions.remove(at: index)
                        HapticManager.light()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(KlarColors.negative)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(KlarColors.surface)
    }

    // MARK: - Excel Import Button
    private var excelImportButton: some View {
        Button {
            showExcelPicker = true
            HapticManager.medium()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tablecells.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(KlarColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("IMPORT EXCEL / CSV")
                        .font(KlarFonts.label(13))
                        .fontWeight(.bold)
                        .foregroundStyle(KlarColors.primary)
                    Text("XLSX, XLS, CSV — Bank statements")
                        .font(KlarFonts.label(10))
                        .foregroundStyle(KlarColors.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KlarColors.secondary)
            }
            .padding(16)
            .background(KlarColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KlarColors.border, lineWidth: 1)
            )
        }
    }

    // MARK: - Excel Import Handler
    private func handleExcelImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let name = url.lastPathComponent
                let ext = url.pathExtension.uppercased()
                let entryId = UUID()

                let fileType: String
                switch ext {
                case "XLSX", "XLS": fileType = "XLS"
                case "CSV", "TXT": fileType = "CSV"
                default: fileType = "XLS"
                }

                let entry = UploadEntry(
                    id: entryId,
                    name: name,
                    fileType: fileType,
                    status: .parsing,
                    statusMessage: "Parsing...",
                    transactionCount: 0
                )
                uploads.append(entry)

                currentParsingAccount = accountName.isEmpty ? "Imported" : accountName

                Task {
                    await parseExcelFileAsync(url: url, entryId: entryId, account: currentParsingAccount)
                }
            }
        case .failure(let error):
            parseErrorMessage = error.localizedDescription
            showParseError = true
        }
    }

    private func parseExcelFileAsync(url: URL, entryId: UUID, account: String) async {
        let service = ImportService()
        do {
            let result = try await service.importFile(at: url)

            await MainActor.run {
                if result.transactions.isEmpty {
                    updateUploadEntry(entryId, status: .needsReview,
                        message: "No transactions found",
                        count: 0)
                    parseErrorMessage = "No transactions could be parsed from the file."
                    showParseError = true
                } else {
                    let duplicates = DuplicateDetector.findDuplicates(
                        newTransactions: result.transactions,
                        existing: Array(existingTransactions)
                    )

                    let duplicateIDs = Set(duplicates.map { $0.new.id })
                    let nonDuplicates = result.transactions.filter { !duplicateIDs.contains($0.id) }

                    currentImportSource = result.source
                    pendingTransactions.append(contentsOf: nonDuplicates)

                    if !result.warnings.isEmpty || result.skippedRows > 0 {
                        excelImportWarnings = result.warnings
                        importSkippedRows = result.skippedRows
                        showImportWarnings = true
                    }

                    if !duplicates.isEmpty {
                        conflictPairs = duplicates
                        updateUploadEntry(entryId, status: .needsReview,
                            message: "\(result.transactions.count) parsed, \(duplicates.count) potential duplicates",
                            count: result.transactions.count)
                        showConflictResolver = true
                    } else {
                        updateUploadEntry(entryId, status: .success,
                            message: "\(result.transactions.count) transactions parsed",
                            count: result.transactions.count)
                    }
                    HapticManager.success()
                }
            }
        } catch {
            await MainActor.run {
                updateUploadEntry(entryId, status: .needsReview,
                    message: error.localizedDescription, count: 0)
                parseErrorMessage = error.localizedDescription
                showParseError = true
                HapticManager.error()
            }
        }
    }

    // MARK: - File Import Handler (PDF)
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let name = url.lastPathComponent
                let ext = url.pathExtension.uppercased()
                let entryId = UUID()

                let entry = UploadEntry(
                    id: entryId,
                    name: name,
                    fileType: ext == "PDF" ? "PDF" : "CSV",
                    status: .parsing,
                    statusMessage: "Parsing...",
                    transactionCount: 0
                )
                uploads.append(entry)

                currentParsingAccount = accountName.isEmpty ? "Imported" : accountName

                Task {
                    await parseFileAsync(url: url, entryId: entryId, account: currentParsingAccount)
                }
            }
        case .failure(let error):
            parseErrorMessage = error.localizedDescription
            showParseError = true
        }
    }

    private func parseFileAsync(url: URL, entryId: UUID, account: String) async {
        let parser = StatementParser()
        do {
            let result = try await parser.parseFile(at: url, accountName: account)
            if !result.debugLog.isEmpty {
                print("=== Import Debug Log ===")
                for entry in result.debugLog { print(entry) }
                print("========================")
            }

            await MainActor.run {
                if result.transactions.isEmpty {
                    updateUploadEntry(entryId, status: .needsReview,
                        message: result.errors.first ?? "No transactions found",
                        count: 0)
                    if let errorMsg = result.errors.first {
                        parseErrorMessage = errorMsg
                        showParseError = true
                    }
                } else {
                    let duplicates = DuplicateDetector.findDuplicates(
                        newTransactions: result.transactions,
                        existing: Array(existingTransactions)
                    )

                    let duplicateIDs = Set(duplicates.map { $0.new.id })
                    let nonDuplicates = result.transactions.filter { !duplicateIDs.contains($0.id) }

                    currentImportSource = result.source
                    pendingTransactions.append(contentsOf: nonDuplicates)

                    if !duplicates.isEmpty {
                        conflictPairs = duplicates
                        updateUploadEntry(entryId, status: .needsReview,
                            message: "\(result.transactions.count) parsed, \(duplicates.count) potential duplicates",
                            count: result.transactions.count)
                        showConflictResolver = true
                    } else {
                        updateUploadEntry(entryId, status: .success,
                            message: "\(result.transactions.count) transactions parsed",
                            count: result.transactions.count)
                    }
                    HapticManager.success()
                }
            }
        } catch {
            await MainActor.run {
                updateUploadEntry(entryId, status: .needsReview,
                    message: error.localizedDescription, count: 0)
                parseErrorMessage = error.localizedDescription
                showParseError = true
                HapticManager.error()
            }
        }
    }

    private func updateUploadEntry(_ id: UUID, status: UploadStatus, message: String, count: Int) {
        if let index = uploads.firstIndex(where: { $0.id == id }) {
            uploads[index].status = status
            uploads[index].statusMessage = message
            uploads[index].transactionCount = count
        }
    }

    // MARK: - Transaction Insertion
    private func ensureAccountExists(name: String) {
        let accountName = name.isEmpty ? "Imported" : name
        if !accounts.contains(where: { $0.name == accountName }) {
            let account = Account(name: accountName, type: selectedAccountType, balance: 0)
            modelContext.insert(account)
        }
    }

    private func addSingleTransaction(_ row: StatementParser.ParsedRow, at index: Int) {
        let rulesArray = Array(rules)
        let merchant = AutoCategorizer.extractMerchant(from: row.description)
        let category = AutoCategorizer.categorize(description: row.description, rules: rulesArray)
        let account = currentParsingAccount.isEmpty ? "Imported" : currentParsingAccount

        ensureAccountExists(name: account)

        let transaction = Transaction(
            date: row.date,
            merchant: merchant,
            amount: row.type == .income ? row.amount : -row.amount,
            category: category,
            account: account,
            type: row.type,
            importSource: currentImportSource,
            notes: row.description
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        pendingTransactions.remove(at: index)
    }

    private func addAllPendingTransactions() {
        let rulesArray = Array(rules)
        let account = currentParsingAccount.isEmpty ? "Imported" : currentParsingAccount

        ensureAccountExists(name: account)

        for row in pendingTransactions {
            let merchant = AutoCategorizer.extractMerchant(from: row.description)
            let category = AutoCategorizer.categorize(description: row.description, rules: rulesArray)

            let transaction = Transaction(
                date: row.date,
                merchant: merchant,
                amount: row.type == .income ? row.amount : -row.amount,
                category: category,
                account: account,
                type: row.type,
                importSource: currentImportSource,
                notes: row.description
            )
            modelContext.insert(transaction)
        }
        try? modelContext.save()
        pendingTransactions.removeAll()
    }

    private func handleResolvedConflicts(_ resolved: [StatementParser.ParsedRow]) {
        pendingTransactions.append(contentsOf: resolved)
        conflictPairs.removeAll()
    }

    // MARK: - Helpers
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: date)
    }

    private func uploadBadgeColor(_ fileType: String) -> Color {
        switch fileType {
        case "PDF": return .red
        case "XLS": return .green
        default: return KlarColors.positive
        }
    }

    private func categorySymbol(for category: String) -> String {
        switch category.lowercased() {
        case "shopping": return "bag.fill"
        case "entertainment": return "tv.fill"
        case "health": return "heart.fill"
        case "finance": return "banknote.fill"
        case "transport": return "car.fill"
        case "utilities": return "bolt.fill"
        case "food": return "fork.knife"
        case "income": return "indianrupeesign.circle.fill"
        default: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Upload Entry Model
struct UploadEntry: Identifiable {
    let id: UUID
    let name: String
    let fileType: String
    var status: UploadStatus
    var statusMessage: String
    var transactionCount: Int
}
