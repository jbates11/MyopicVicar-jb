# Rails Action Lifecycle Diagrams

## Diagram 1: Normal (Working) Flow

When a Rails action exists and works correctly:

```mermaid
graph LR
    A["Browser<br/>GET /emendation_types/1"] 
    B["Router<br/>Matches Route"]
    C["Extract Params<br/>id: 1, action: show<br/>controller: emendation_types"]
    D["Load Controller<br/>EmendationTypesController"]
    E["Run before_action<br/>set_emendation_type"]
    F["Execute<br/>show action"]
    G["Render Template<br/>show.html.erb"]
    H["Send HTML<br/>to Browser"]
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    
    style A fill:#e1f5ff
    style H fill:#c8e6c9
    style F fill:#fff9c4
```

---

## Diagram 2: Current (Broken) Flow

**This is what's happening in your code:**

```mermaid
graph LR
    A["Browser<br/>GET /emendation_types/1"] 
    B["Router<br/>Matches Route"]
    C["Extract Params<br/>id: 1, action: show<br/>controller: emendation_types"]
    D["Load Controller<br/>EmendationTypesController"]
    E{"Is there a<br/>show() method?"}
    F["❌ NO!<br/>Crash!"]
    G["Error Page<br/>Unknown Action"]
    
    A --> B
    B --> C
    C --> D
    D --> E
    E -->|Method Missing| F
    F --> G
    
    style A fill:#e1f5ff
    style F fill:#ffcdd2
    style G fill:#ffcdd2
    style E fill:#ffe082
```

---

## Diagram 3: Controller Method Comparison

**What You Have vs. What Rails Expects**

```mermaid
graph TD
    subgraph Current["❌ CURRENT (Broken)"]
        A1["before_action declaration<br/>declares show exists"]
        A2["def new...end"]
        A3["def create...end"]
        A4["def edit...end"]
        A5["def update...end"]
        A6["def destroy...end"]
        A7["❌ NO show method!"]
    end
    
    subgraph Expected["✅ EXPECTED (Working)"]
        B1["def index...end"]
        B2["def new...end"]
        B3["def create...end"]
        B4["def show...end"]
        B5["def edit...end"]
        B6["def update...end"]
        B7["def destroy...end"]
    end
    
    style A7 fill:#ffcdd2
    style B4 fill:#c8e6c9
```

---

## Diagram 4: Routes vs. Actions

**What Creates Routes vs. What Handles Them**

```mermaid
graph LR
    A["config/routes.rb<br/>resources :emendation_types"]
    B["Generates 7 Routes<br/>GET /emendation_types/1<br/>POST /emendation_types<br/>PATCH /emendation_types/1<br/>etc."]
    C["Controller Must Have<br/>Matching Methods<br/>index, new, create<br/>show, edit, update<br/>destroy"]
    D1["EmendationTypesController<br/>def index...end<br/>def show...end<br/>def create...end<br/>etc."]
    
    A --> B
    B --> C
    C --> D1
    
    style A fill:#e3f2fd
    style B fill:#f3e5f5
    style C fill:#fff3e0
    style D1 fill:#e8f5e9
```

---

## Diagram 5: The Error Chain

**How the error message gets generated**

```mermaid
graph TD
    A["User visits URL<br/>/emendation_types/99"]
    B["Rails Router<br/>Looks up route"]
    C["Route found:<br/>GET /emendation_types/:id<br/>maps to<br/>show action"]
    D["Rails looks in<br/>EmendationTypesController<br/>for method: show"]
    E{"Found?"}
    F["Method exists<br/>Continue executing"]
    G["Method does NOT exist<br/>Rails exceptions"]
    H["ActionController<br/>::UnknownActionError"]
    I["Browser displays<br/>error page"]
    
    A --> B
    B --> C
    C --> D
    D --> E
    E -->|YES| F
    E -->|NO| G
    G --> H
    H --> I
    
    style A fill:#e1f5ff
    style H fill:#ffcdd2
    style I fill:#ffcdd2
    style F fill:#c8e6c9
```

---

## Diagram 6: Before Action Hook Execution Order

**This explains why before_action doesn't help you**

```mermaid
graph LR
    A["Request arrives<br/>for show action"]
    B["Rails checks:<br/>Does show<br/>method exist?"]
    C{"Exists?"}
    R1["NO ❌<br/>Error here!"]
    D["YES ✅<br/>Continue"]
    E["Before executing show,<br/>run before_action hooks<br/>set_emendation_type"]
    F["Execute show<br/>method body"]
    
    A --> B
    B --> C
    C -->|No| R1
    C -->|Yes| D
    D --> E
    E --> F
    
    style R1 fill:#ffcdd2
    style D fill:#c8e6c9
```

---

## Diagram 7: Controller Method Structure

**Anatomy of a properly implemented action with before_action**

```
┌─────────────────────────────────────────────────────┐
│ EmendationTypesController                           │
├─────────────────────────────────────────────────────┤
│                                                     │
│  before_action :set_emendation_type,                │
│               only: [:show, :edit, :update, :destroy]
│                     ↑                               │
│              These actions MUST be defined below    │
│                                                     │
│  def index                                          │
│    @emendation_types = EmendationType.all           │
│  end                                                │
│                                                     │
│  def show                    ← REQUIRED!            │
│    # @emendation_type already loaded by before_act │
│  end                                                │
│                                                     │
│  def new                                            │
│    @emendation_type = EmendationType.new            │
│  end                                                │
│                                                     │
│  def create                                         │
│    # ... implementation                             │
│  end                                                │
│                                                     │
│  private                                            │
│                                                     │
│  def set_emendation_type                            │
│    @emendation_type = EmendationType.find(params[:id])
│  end                        ↑ Loads the object      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

