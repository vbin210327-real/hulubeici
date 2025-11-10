import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var avatarImageData: Data?
    @Binding var userName: String
    @State private var editingName: String
    @State private var showPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCropper = false

    init(avatarImageData: Binding<Data?>, userName: Binding<String>) {
        self._avatarImageData = avatarImageData
        self._userName = userName
        self._editingName = State(initialValue: userName.wrappedValue)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Avatar with edit button
                Button(action: {
                    showPhotoPicker = true
                }) {
                    ZStack(alignment: .bottomTrailing) {
                        if let data = avatarImageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 120, height: 120)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(Color(.systemGray3))
                                }
                        }

                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 36, height: 36)

                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 34, height: 34)

                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .offset(x: -2, y: -2)
                    }
                }
                .buttonStyle(.plain)

                // Title with TextField
                TextField("编辑昵称", text: $editingName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Save button
                Button(action: {
                    Haptic.trigger(.medium)
                    userName = editingName
                    dismiss()
                }) {
                    Text("保存")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)

                // Cancel button
                Button(action: {
                    Haptic.trigger(.light)
                    dismiss()
                }) {
                    Text("取消")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }

                Spacer()
            }
            .padding(.vertical, 40)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            if let newItem {
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        showCropper = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCropper) {
            if let image = selectedImage {
                AvatarCropperView(
                    image: image,
                    onCrop: { croppedData in
                        avatarImageData = croppedData
                        showCropper = false
                        selectedImage = nil
                        selectedItem = nil
                    },
                    onCancel: {
                        showCropper = false
                        selectedImage = nil
                        selectedItem = nil
                    }
                )
            }
        }
    }
}
