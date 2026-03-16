import SwiftUI
import UniformTypeIdentifiers

struct ImportHubView: View {
    @State private var accountName = ""
    @State private var uploads: [UploadFile] = MockData.uploadFiles
    @State private var showDocumentPicker = false
    @State private var showConflictResolver = false
    @State private var isDragTargeted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("IMPORT HUB")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(.white)

                    Text("Upload Files")
                        .font(KlarFonts.heading(18))
                        .foregroundStyle(KlarColors.secondary)

                    Text("Upload a csv, pdf, or photo of receipt. Parsed transactions go to your inbox for review before being added.")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(KlarColors.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Drop Zone
                dropZone
                    .padding(.horizontal, 20)

                // Account Name Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "creditcard")
                            .foregroundStyle(KlarColors.secondary)
                        Text("ACCOUNT NAME")
                            .font(KlarFonts.label(12))
                            .tracking(1)
                            .foregroundStyle(KlarColors.secondary)
                    }

                    TextField("e.g. HDFC Savings, ICICI Credit Card", text: $accountName)
                        .font(KlarFonts.body(14))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(KlarColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("Labels where each transaction came from.")
                        .font(KlarFonts.label(11))
                        .foregroundStyle(KlarColors.secondary)
                }
                .padding(.horizontal, 20)

                // Uploads Section
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "UPLOADS")
                        .padding(.horizontal, 20)

                    VStack(spacing: 1) {
                        ForEach(uploads) { file in
                            uploadRow(file)
                        }
                    }
                }

                Spacer(minLength: 100)
            }
        }
        .background(KlarColors.background)
        .sheet(isPresented: $showConflictResolver) {
            ConflictResolverView()
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private var dropZone: some View {
        Button {
            showDocumentPicker = true
        } label: {
            VStack(spacing: 14) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)

                Text("DROP YOUR FILES HERE OR BROWSE")
                    .font(KlarFonts.label(13))
                    .tracking(1)
                    .foregroundStyle(.white)

                Text("MAX FILE SIZE UPTO 100MB")
                    .font(KlarFonts.label(10))
                    .tracking(0.5)
                    .foregroundStyle(KlarColors.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isDragTargeted ? Color.white : KlarColors.inactive,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDragTargeted ? KlarColors.surfaceElevated : .clear)
            )
        }
        .dropDestination(for: Data.self) { items, location in
            // Handle dropped files
            return true
        } isTargeted: { targeted in
            isDragTargeted = targeted
        }
    }

    private func uploadRow(_ file: UploadFile) -> some View {
        HStack(spacing: 14) {
            // File type icon
            RoundedRectangle(cornerRadius: 8)
                .fill(file.fileType == "PDF" ? Color.red.opacity(0.15) : KlarColors.positive.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(file.fileType)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(file.fileType == "PDF" ? .red : KlarColors.positive)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(KlarFonts.body(14))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(file.size)
                    .font(KlarFonts.label(11))
                    .foregroundStyle(KlarColors.secondary)
            }

            Spacer()

            StatusBadge(status: file.status)

            if file.status == .needsReview {
                Button {
                    showConflictResolver = true
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(KlarColors.negative)
                        .font(.system(size: 14))
                }
            }

            Button {
                uploads.removeAll { $0.id == file.id }
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

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let name = url.lastPathComponent
                let ext = url.pathExtension.uppercased()
                let newFile = UploadFile(
                    name: name,
                    size: "Calculating...",
                    fileType: ext == "PDF" ? "PDF" : "CSV",
                    status: .parsing
                )
                uploads.append(newFile)
            }
        case .failure:
            break
        }
    }
}
