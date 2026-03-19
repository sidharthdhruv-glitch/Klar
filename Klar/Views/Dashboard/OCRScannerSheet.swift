import SwiftUI
import VisionKit
import Vision

struct OCRScannerSheet: View {
    let rules: [Rule]
    let onAdd: (Transaction) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scannedText = ""
    @State private var showScanner = true
    @State private var parsedMerchant = ""
    @State private var parsedAmount = ""
    @State private var parsedDate = Date()
    @State private var parsedCategory = "Misc"
    @State private var selectedType: TransactionType = .expense
    @State private var notes = ""
    @FocusState private var isAmountFocused: Bool

    let categoryNames = ["Food", "Transport", "Shopping", "Entertainment",
                         "Health", "Utilities", "Finance", "Misc", "Income"]

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
                Text("SCAN BILL")
                    .font(KlarFonts.heading(18))
                    .foregroundStyle(KlarColors.primary)
                Spacer()
                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlarColors.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            if scannedText.isEmpty {
                // Show instructions before scanning
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(KlarColors.inactive)
                    Text("Scan a bill or receipt")
                        .font(KlarFonts.heading(16))
                        .foregroundStyle(KlarColors.secondary)
                    Text("Point your camera at a receipt to extract the amount and details automatically.")
                        .font(KlarFonts.label(12))
                        .foregroundStyle(KlarColors.inactive)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        showScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Open Scanner")
                        }
                        .font(KlarFonts.label(14))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(KlarColors.primary)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                Spacer()
            } else {
                // Show parsed results for review
                ScrollView {
                    VStack(spacing: 16) {
                        // Scanned text preview
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SCANNED TEXT")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)

                            Text(scannedText.prefix(200) + (scannedText.count > 200 ? "..." : ""))
                                .font(KlarFonts.label(11))
                                .foregroundStyle(KlarColors.inactive)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(KlarColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Type picker
                        HStack(spacing: 0) {
                            ForEach(TransactionType.allCases, id: \.self) { type in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedType = type
                                    }
                                } label: {
                                    Text(type.rawValue.uppercased())
                                        .font(KlarFonts.label(12))
                                        .tracking(1)
                                        .foregroundStyle(selectedType == type ? .white : KlarColors.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedType == type
                                            ? (type == .expense ? KlarColors.negative : KlarColors.positive)
                                            : Color.clear
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .background(KlarColors.surfaceElevated)
                        .clipShape(Capsule())

                        // Amount
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AMOUNT")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)

                            HStack {
                                Text("₹")
                                    .font(KlarFonts.heading(20))
                                    .foregroundStyle(KlarColors.primary)
                                TextField("0", text: $parsedAmount)
                                    .font(KlarFonts.heading(20))
                                    .foregroundStyle(KlarColors.primary)
                                    .keyboardType(.decimalPad)
                                    .focused($isAmountFocused)
                            }
                            .padding(14)
                            .background(KlarColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Merchant
                        VStack(alignment: .leading, spacing: 6) {
                            Text("MERCHANT")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)

                            TextField("Merchant name", text: $parsedMerchant)
                                .font(KlarFonts.body(15))
                                .foregroundStyle(KlarColors.primary)
                                .padding(14)
                                .background(KlarColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Date
                        VStack(alignment: .leading, spacing: 6) {
                            Text("DATE")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)

                            DatePicker("", selection: $parsedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(10)
                                .background(KlarColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Category
                        VStack(alignment: .leading, spacing: 6) {
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
                                        parsedCategory = name
                                    } label: {
                                        Text(name.uppercased())
                                            .font(KlarFonts.label(11))
                                            .foregroundStyle(parsedCategory == name ? .white : KlarColors.secondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(parsedCategory == name ? KlarColors.categoryColor(for: name) : KlarColors.surfaceElevated)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Save button
                Button {
                    guard let amountValue = Double(parsedAmount), amountValue > 0 else { return }
                    let merchant = parsedMerchant.isEmpty ? "Scanned Bill" : parsedMerchant
                    let txn = Transaction(
                        date: parsedDate,
                        merchant: merchant,
                        amount: selectedType == .income ? amountValue : -amountValue,
                        category: parsedCategory,
                        account: "Manual",
                        type: selectedType,
                        importSource: .manual,
                        notes: "OCR scan: " + String(scannedText.prefix(100))
                    )
                    onAdd(txn)
                } label: {
                    Text("Save Transaction")
                        .font(KlarFonts.label(14))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KlarColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(KlarColors.background)
        .presentationDetents([.large])
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { text in
                scannedText = text
                parseScannedText(text)
                showScanner = false
            } onCancel: {
                showScanner = false
                if scannedText.isEmpty {
                    dismiss()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isAmountFocused = false }
                    .fontWeight(.semibold)
            }
        }
    }

    private func parseScannedText(_ text: String) {
        let lower = text.lowercased()

        // Extract amount — look for ₹ or Rs or common patterns
        let amountPatterns = [
            #"(?:₹|rs\.?|inr)\s*([\d,]+\.?\d*)"#,
            #"(?:total|amount|grand total|net|due)[:\s]*([\d,]+\.?\d*)"#,
            #"([\d,]+\.\d{2})"#
        ]

        for pattern in amountPatterns {
            if let match = text.range(of: pattern, options: .regularExpression, range: text.startIndex..<text.endIndex) {
                let matched = String(text[match])
                let digits = matched.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                if let value = Double(digits), value > 0 {
                    parsedAmount = String(format: "%.0f", value)
                    break
                }
            }
        }

        // Extract merchant — use first meaningful line
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 2 }

        if let firstLine = lines.first {
            let cleaned = firstLine.prefix(40)
            parsedMerchant = String(cleaned)
        }

        // Auto-categorize using existing rules
        parsedCategory = AutoCategorizer.categorize(description: lower, rules: rules)
        if parsedCategory == "Income" {
            parsedCategory = "Misc"
        }
    }
}

// MARK: - VisionKit Document Scanner
struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (String) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var fullText = ""

            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                guard let cgImage = image.cgImage else { continue }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate

                let handler = VNImageRequestHandler(cgImage: cgImage)
                try? handler.perform([request])

                if let observations = request.results {
                    let pageText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                    fullText += pageText + "\n"
                }
            }

            let result = fullText
            controller.dismiss(animated: true) { [self] in
                self.onScan(result)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.onCancel()
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.onCancel()
            }
        }
    }
}
