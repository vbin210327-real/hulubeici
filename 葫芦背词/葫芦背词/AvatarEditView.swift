import SwiftUI
import PhotosUI

struct AvatarEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var avatarImageData: Data?
    @State private var showPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCropper = false

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Current avatar display
                if let data = avatarImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.5))
                        }
                }

                Spacer()

                // Upload button
                Button(action: {
                    showPhotoPicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                        Text("上传新头像")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
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
                        dismiss()
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

struct AvatarCropperView: View {
    let image: UIImage
    let onCrop: (Data) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title
                Text("裁剪头像")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                Spacer()

                // Crop area
                ZStack {
                    // Dimmed overlay
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .ignoresSafeArea()

                    // Image
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                    }
                    .frame(width: cropSize, height: cropSize)
                    .clipShape(Circle())

                    // Circle overlay
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropSize, height: cropSize)
                }

                Spacer()

                // Buttons
                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(12)
                    }

                    Button(action: cropAndSave) {
                        Text("确认")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private func cropAndSave() {
        // Create a renderer for the cropped image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropSize * 3, height: cropSize * 3))

        let croppedImage = renderer.image { context in
            let drawRect = CGRect(
                x: -offset.width * 3,
                y: -offset.height * 3,
                width: image.size.width * scale * 3,
                height: image.size.height * scale * 3
            )

            // Clip to circle
            let path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: cropSize * 3, height: cropSize * 3))
            path.addClip()

            image.draw(in: drawRect)
        }

        // Convert to JPEG data with compression
        if let data = croppedImage.jpegData(compressionQuality: 0.8) {
            Haptic.trigger(.medium)
            onCrop(data)
        }
    }
}
