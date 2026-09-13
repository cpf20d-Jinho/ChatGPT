import PhotosUI
import SwiftUI
import UIKit

struct ACCView: View {
    @State private var selection: [PhotosPickerItem] = []
    @State private var photos: [ACCPhoto] = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var photoPendingDeletion: ACCPhoto?
    @State private var page = 0

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 180), spacing: 12)]
    private let pageSize = 60
    private var visiblePhotos: [ACCPhoto] {
        Array(photos.dropFirst(page * pageSize).prefix(pageSize))
    }

    var body: some View {
        ScrollView {
            if photos.isEmpty && !isImporting {
                ContentUnavailableView(
                    "저장된 ACC 사진이 없습니다",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("사진을 추가하면 이 기기의 ACC 자료함에 저장됩니다.")
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                if photos.count > pageSize {
                    HStack {
                        Button("이전") { page -= 1 }
                            .disabled(page == 0)
                        Spacer()
                        Text("\(page + 1) / \((photos.count - 1) / pageSize + 1)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("다음") { page += 1 }
                            .disabled((page + 1) * pageSize >= photos.count)
                    }
                    .padding(.horizontal)
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visiblePhotos) { photo in
                        ACCPhotoTile(photo: photo) { photoPendingDeletion = photo }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("ACC")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PhotosPicker(selection: $selection, maxSelectionCount: 20, matching: .images) {
                    Label("사진 추가", systemImage: "plus")
                }
                .disabled(isImporting)
            }
        }
        .overlay(alignment: .bottom) {
            if isImporting { ProgressView("사진 저장 중…").padding().background(.regularMaterial) }
        }
        .task { await reload() }
        .onChange(of: selection) { _, newValue in
            guard !newValue.isEmpty else { return }
            selection = []
            Task { await importPhotos(newValue) }
        }
        .confirmationDialog("사진을 삭제하시겠습니까?", isPresented: Binding(
            get: { photoPendingDeletion != nil },
            set: { if !$0 { photoPendingDeletion = nil } }
        )) {
            Button("삭제", role: .destructive) {
                guard let photo = photoPendingDeletion else { return }
                photoPendingDeletion = nil
                Task {
                    do { try await ACCPhotoStore.shared.remove(photo); await reload() }
                    catch { errorMessage = error.localizedDescription }
                }
            }
        } message: {
            Text("이 기기에 저장된 원본과 미리보기가 삭제됩니다.")
        }
        .alert("ACC 사진", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func reload() async {
        do {
            photos = try await ACCPhotoStore.shared.photos()
            page = min(page, max(0, (photos.count - 1) / pageSize))
        }
        catch { errorMessage = error.localizedDescription }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer { isImporting = false }
        var failed = 0
        for item in items {
            do {
                guard let imported = try await item.loadTransferable(type: ACCImportedPhoto.self) else {
                    failed += 1
                    continue
                }
                _ = try await ACCPhotoStore.shared.add(from: imported.temporaryURL)
            } catch { failed += 1 }
        }
        await reload()
        if failed > 0 { errorMessage = "\(failed)장의 사진을 저장하지 못했습니다. 지원 형식과 파일 크기(최대 200 MB)를 확인해 주세요." }
    }
}

private struct ACCPhotoTile: View {
    let photo: ACCPhoto
    let onDelete: () -> Void
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(.quaternary)
                        .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(photo.createdAt, format: .dateTime.year().month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ACC 사진, \(photo.createdAt.formatted(date: .abbreviated, time: .omitted))")
        .contextMenu { Button("삭제", systemImage: "trash", role: .destructive, action: onDelete) }
        .task(id: photo.id) {
            guard let data = try? await ACCPhotoStore.shared.thumbnailData(for: photo) else { return }
            thumbnail = UIImage(data: data)
        }
    }
}

