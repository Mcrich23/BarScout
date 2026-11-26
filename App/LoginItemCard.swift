import AppKit
import ServiceManagement
import SwiftUI

struct LoginItemCard: View {
  @State private var status: SMAppService.Status = .notRegistered
  @State private var errorMessage = ""
  @State private var showsError = false

  var body: some View {
    SetupCard {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 12) {
          SetupCardIcon(symbol: "power")

          Toggle(isOn: Binding(get: { isRegistered }, set: updateRegistration)) {
            Text("Open at Login")
              .fontWeight(.semibold)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .toggleStyle(.switch)
        }

        if status == .requiresApproval {
          Button("Allow in System Settings", action: SMAppService.openSystemSettingsLoginItems)
            .buttonStyle(.link)
            .padding(.leading, 44)
        }
      }
    }
    .onAppear(perform: refreshStatus)
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
      refreshStatus()
    }
    .alert("Couldn’t change Open at Login", isPresented: $showsError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
  }

  private var isRegistered: Bool {
    status == .enabled || status == .requiresApproval
  }

  private func refreshStatus() {
    status = SMAppService.mainApp.status
  }

  private func updateRegistration(_ enabled: Bool) {
    let service = SMAppService.mainApp
    status = service.status
    guard enabled != isRegistered else { return }

    do {
      if enabled {
        try service.register()
      } else {
        try service.unregister()
      }
      status = service.status
    } catch {
      status = service.status
      if enabled != isRegistered {
        errorMessage = error.localizedDescription
        showsError = true
      }
    }
  }
}
