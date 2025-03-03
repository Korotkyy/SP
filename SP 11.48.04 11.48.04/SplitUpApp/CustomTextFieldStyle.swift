import SwiftUI

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.customBeige)
            .cornerRadius(12)
            .foregroundColor(.customDarkNavy)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.customAccent.opacity(0.3), lineWidth: 1)
            )
    }
}
