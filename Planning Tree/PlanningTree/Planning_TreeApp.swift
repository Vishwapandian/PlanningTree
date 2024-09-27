import SwiftUI
import CoreData

// MARK: - Persistence Controller

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "Planning_Tree")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Unable to load Core Data Store: \(error)")
            } else {
                print("Successfully loaded Core Data Store")
            }
        }

    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Plan.name, ascending: true)],
        animation: .default)
    private var plans: FetchedResults<Plan>

    @State private var showingAddPlan = false

    var body: some View {
        NavigationView {
            VStack {
                if plans.isEmpty {
                    Text("Nothing to see here! Try adding a plan by pressing the '+' button on the top right corner of the screen.")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                        .foregroundColor(.gray)
                } else {
                    List {
                        ForEach(plans) { plan in
                            if let rootNode = plan.rootNode {
                                NavigationLink(destination: PlanDetailView(planNode: rootNode)) {
                                    HStack {
                                        Text(plan.name ?? "Untitled Plan")
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .onDelete(perform: deletePlans)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("My Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPlan = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                AddPlanView()
            }
        }
    }

    private func deletePlans(offsets: IndexSet) {
        withAnimation {
            offsets.map { plans[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            // Handle the error appropriately
            print("Error saving context: \(error)")
        }
    }
}

// MARK: - Add Plan View

struct AddPlanView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    @State private var newPlanName: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Plan Name", text: $newPlanName)
                }
                Section {
                    Button("Add Plan") {
                        addPlan()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(newPlanName.isEmpty)
                }
            }
            .navigationTitle("New Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func addPlan() {
        let newPlan = Plan(context: viewContext)
        newPlan.id = UUID()
        newPlan.name = newPlanName

        let rootNode = PlanNode(context: viewContext)
        rootNode.id = UUID()
        rootNode.title = newPlanName
        rootNode.plan = newPlan
        newPlan.rootNode = rootNode

        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save new plan: \(error)")
        }
    }
}

// MARK: - Plan Detail View

struct PlanDetailView: View {
    @ObservedObject var planNode: PlanNode
    @State private var showingAddNode = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                NodeView(node: planNode)
            }
            .padding()
        }
        .navigationTitle(planNode.title ?? "Untitled Node")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddNode = true }) {
                    //Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddNode) {
            AddNodeView(parentNode: planNode)
        }
    }
}

// MARK: - Add Node View

struct AddNodeView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var parentNode: PlanNode
    @State private var newNodeTitle: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Node Title", text: $newNodeTitle)
                }
                Section {
                    Button("Add Node") {
                        addNode()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(newNodeTitle.isEmpty)
                }
            }
            .navigationTitle("New Node")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func addNode() {
        let childNode = PlanNode(context: viewContext)
        childNode.id = UUID()
        childNode.title = newNodeTitle
        childNode.parent = parentNode

        parentNode.addToChildren(childNode)

        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save new node: \(error)")
        }
    }
}

// MARK: - Node View

struct NodeView: View {
    @ObservedObject var node: PlanNode
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddChild = false
    @State private var showingEditNode = false
    @State private var editedTitle: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(node.title ?? "Untitled Node")
                    .font(.headline)
                    .foregroundColor(node.isHighlighted ? .green : .primary)
                Spacer()
                Button(action: {
                    node.isHighlighted.toggle()
                    saveContext()
                }) {
                    Image(systemName: node.isHighlighted ? "star.fill" : "star")
                        .foregroundColor(node.isHighlighted ? .green : .gray)
                }
                .buttonStyle(BorderlessButtonStyle())
                Button(action: { showingAddChild = true }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
                Menu {
                    Button(action: {
                        editedTitle = node.title ?? ""
                        showingEditNode = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    if node.parent != nil {
                        Button(role: .destructive, action: {
                            deleteNode()
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.gray)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
            .padding(.leading, CGFloat(nodeLevel(node: node)) * 20)

            ForEach(node.childrenArray, id: \.self) { child in
                NodeView(node: child)
            }
        }
        .sheet(isPresented: $showingAddChild) {
            AddNodeView(parentNode: node)
        }
        .sheet(isPresented: $showingEditNode) {
            NavigationView {
                Form {
                    Section {
                        TextField("Node Title", text: $editedTitle)
                    }
                    Section {
                        Button("Save") {
                            node.title = editedTitle
                            saveContext()
                            showingEditNode = false
                        }
                        .disabled(editedTitle.isEmpty)
                    }
                }
                .navigationTitle("Edit Node")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingEditNode = false
                        }
                    }
                }
            }
        }
    }

    private func deleteNode() {
        if let parent = node.parent {
            parent.removeFromChildren(node)
        }
        viewContext.delete(node)
        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    // Helper function to determine node level for indentation
    func nodeLevel(node: PlanNode) -> Int {
        var level = 0
        var currentNode = node.parent
        while currentNode != nil {
            level += 1
            currentNode = currentNode?.parent
        }
        return level
    }
}

// MARK: - Core Data Extensions

extension Plan { }

extension PlanNode {
    var childrenArray: [PlanNode] {
        let set = children as? Set<PlanNode> ?? []
        return set.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }
}

// MARK: - App Entry Point

@main
struct PlanningTreeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

// MARK: - Preview Provider

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
