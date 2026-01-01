//
//  ContentView.swift
//  EarthLord
//
//  Created by 范有为 on 2026/1/1.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            Text("Developed by Wayne")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(.top, 20)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
