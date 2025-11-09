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
                        let imageSize = calculateImageSize(in: geometry.size)
                        let minScale = cropSize / min(imageSize.width, imageSize.height)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(max(scale, minScale))
                            .offset(limitedOffset(imageSize: imageSize, currentScale: max(scale, minScale)))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = max(newScale, minScale)
                                    }
                                    .onEnded { _ in
                                        lastScale = max(scale, minScale)
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        offset = newOffset
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

    private func calculateImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider - fit to height
            let width = containerSize.height * imageAspect
            return CGSize(width: width, height: containerSize.height)
        } else {
            // Image is taller - fit to width
            let height = containerSize.width / imageAspect
            return CGSize(width: containerSize.width, height: height)
        }
    }

    private func limitedOffset(imageSize: CGSize, currentScale: CGFloat) -> CGSize {
        let scaledWidth = imageSize.width * currentScale
        let scaledHeight = imageSize.height * currentScale

        let maxOffsetX = max(0, (scaledWidth - cropSize) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropSize) / 2)

        let constrainedX = min(max(offset.width, -maxOffsetX), maxOffsetX)
        let constrainedY = min(max(offset.height, -maxOffsetY), maxOffsetY)

        return CGSize(width: constrainedX, height: constrainedY)
    }

    private func cropAndSave() {
        // Calculate the actual display size of the image
        let imageSize = calculateImageSize(in: CGSize(width: cropSize, height: cropSize))
        let minScale = cropSize / min(imageSize.width, imageSize.height)
        let actualScale = max(scale, minScale)

        // Calculate the scaled display size
        let displayWidth = imageSize.width * actualScale
        let displayHeight = imageSize.height * actualScale

        // Get the constrained offset
        let actualOffset = limitedOffset(imageSize: imageSize, currentScale: actualScale)

        // Calculate the crop region in the original image coordinates
        let scaleToOriginal = image.size.width / imageSize.width
        let cropRegionInDisplay = CGRect(
            x: (displayWidth - cropSize) / 2 - actualOffset.width,
            y: (displayHeight - cropSize) / 2 - actualOffset.height,
            width: cropSize,
            height: cropSize
        )

        // Convert to original image coordinates
        let cropRegion = CGRect(
            x: cropRegionInDisplay.origin.x * scaleToOriginal,
            y: cropRegionInDisplay.origin.y * scaleToOriginal,
            width: cropRegionInDisplay.width * scaleToOriginal,
            height: cropRegionInDisplay.height * scaleToOriginal
        )

        // Crop the image
        guard let cgImage = image.cgImage?.cropping(to: cropRegion) else {
            return
        }

        let croppedUIImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        // Create a circular masked version at 3x resolution
        let outputSize = CGSize(width: cropSize * 3, height: cropSize * 3)
        let renderer = UIGraphicsImageRenderer(size: outputSize)

        let finalImage = renderer.image { context in
            // Clip to circle
            let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: outputSize))
            path.addClip()

            // Draw the cropped image
            croppedUIImage.draw(in: CGRect(origin: .zero, size: outputSize))
        }

        // Convert to JPEG data with compression
        if let data = finalImage.jpegData(compressionQuality: 0.8) {
            Haptic.trigger(.medium)
            onCrop(data)
        }
    }
}
