# Quick Reference: Rails Actions and Routes

## What Is an "Action"?

An **action** is a method in a Rails controller that handles a request.

```ruby
class EmendationTypesController < ApplicationController
  def index        # ← This is an action
    @types = EmendationType.all
  end

  def show         # ← This is an action
    @type = EmendationType.find(params[:id])
  end
end
```

---

## Rails RESTful Actions (The Standard 7)

When you write `resources :model` in routes.rb, Rails creates these automatically:

| Action | HTTP Method | URL Pattern | Purpose | Example URL |
|--------|-------------|-------------|---------|-------------|
| `index` | GET | `/model` | List all | `/emendation_types` |
| `new` | GET | `/model/new` | Show new form | `/emendation_types/new` |
| `create` | POST | `/model` | Save new | `/emendation_types` (form submission) |
| `show` | GET | `/model/:id` | View one | `/emendation_types/5` |
| `edit` | GET | `/model/:id/edit` | Show edit form | `/emendation_types/5/edit` |
| `update` | PATCH/PUT | `/model/:id` | Save changes | `/emendation_types/5` (form submission) |
| `destroy` | DELETE | `/model/:id` | Delete one | `/emendation_types/5` (with DELETE method) |

---

## The Error You're Getting

```
Unknown action 'show' could not be found for EmendationTypesController
```

This means:
- ✓ The **route** exists (because `resources :emendation_types` created it)
- ✓ Rails **found the right controller**
- ❌ But the **method** is **not defined**

---

## Checklist: What Should Match

### ✅ Checklist 1: Route Matches Method

```ruby
# config/routes.rb
resources :emendation_types  # ← Creates routes for all 7 actions

# app/controllers/emendation_types_controller.rb
class EmendationTypesController < ApplicationController
  def index; end     # ✓ Has method
  def new; end       # ✓ Has method
  def create; end    # ✓ Has method
  def show; end      # ✓ MUST have method (currently missing!)
  def edit; end      # ✓ Has method
  def update; end    # ✓ Has method
  def destroy; end   # ✓ Has method
end
```

### ✅ Checklist 2: before_action Matches Defined Methods

```ruby
class EmendationTypesController < ApplicationController
  # Only list actions that are actually defined below!
  before_action :set_model, only: [:show, :edit, :update, :destroy]
  #                                ↑ All of these must be defined

  def show; end      # ✓
  def edit; end      # ✓
  def update; end    # ✓
  def destroy; end   # ✓
end
```

### ✅ Checklist 3: Helper Methods Work

```ruby
class EmendationTypesController < ApplicationController
  before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]

  private

  def set_emendation_type
    @emendation_type = EmendationType.find(params[:id])
  end
end
```

When Rails calls the `show` action:
1. Rails checks if method exists → ❌ FAILS (missing method)
2. Never even gets to `before_action`

---

## Common Mistakes

### ❌ Mistake 1: Forgetting the Method Body

```ruby
# WRONG: Declared but not defined
before_action :set_model, only: [:show, :edit, :update, :destroy]

def edit; end
def update; end
def destroy; end
# Missing: show
```

### ❌ Mistake 2: Wrong Method Name

```ruby
# WRONG: Method name doesn't match route
before_action :set_model, only: [:show]

def display; end    # Wrong name!
```

Should be:
```ruby
def show; end       # Correct name
```

### ❌ Mistake 3: Using Routes You Don't Implement

```ruby
# WRONG: Routes tries to use :show but you don't define it
resources :emendation_types
# Creates: /emendation_types/:id → show action

# But you only defined:
def index; end
def new; end
def create; end
# ❌ Missing: show, edit, update, destroy
```

Should be:
```ruby
# OPTION A: Define show
def show; end

# OPTION B: Remove from routes
resources :emendation_types, except: [:show]
```

---

## Quick Fixes

### Fix 1: Add Missing Method (2 lines)

```ruby
def show
  # @emendation_type already loaded by before_action
end
```

### Fix 2: Remove from Routes (1 edit)

```ruby
resources :emendation_types, except: [:show]
```

### Fix 3: Remove from before_action (1 edit)

```ruby
before_action :set_emendation_type, only: [:edit, :update, :destroy]
# Removed :show from the list
```

---

## How to Verify the Fix

### Test 1: Server Doesn't Crash

```bash
rails s
# Should show: "Server is running at..."
```

### Test 2: URL Works

Visit: `http://localhost:3000/emendation_types/1`
- ✓ Should load page or show error about missing template (good!)
- ❌ Should NOT show "Unknown action" error

### Test 3: List Still Works

Visit: `http://localhost:3000/emendation_types`
- ✓ Should display list

---

## Rails Magic to Understand

### When URLs Match to Methods

```ruby
# Route definition
GET /emendation_types/:id  →  EmendationTypesController#show

# What Rails extracts from URL /emendation_types/42:
params[:id]         # The number 42
controller          # emendation_types
action              # show

# What Rails does:
1. Load EmendationTypesController
2. Look for method: show
3. If found: Call it
4. If not found: Error!
```

### How before_action Works

```ruby
class ExampleController < ApplicationController
  before_action :load_data, only: [:show, :edit]

  def show
    # 1. Rails checks: Does show method exist? YES
    # 2. Rails runs: load_data (before_action)
    # 3. Rails runs: show method
  end

  def index
    # 1. Rails checks: Is index in before_action? NO
    # 2. Rails skips: load_data
    # 3. Rails runs: index method
  end

  private
  def load_data
    # This runs BEFORE show or edit, but ONLY if those methods exist
  end
end
```

---

## Decision Tree

```
Do you want users to view one record?
│
├─ YES
│  └─ Add the show method to controller
│     └─ (Optionally create show.html.erb view)
│
└─ NO
   └─ Remove show from routes with: except: [:show]
```

---

## Real-World Example

### The Setup

```ruby
# config/routes.rb
resources :emendation_types

# app/controllers/emendation_types_controller.rb
class EmendationTypesController < ApplicationController
  before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]

  def edit
  end

  def update
    if @emendation_type.update(params)
      redirect_to emendation_types_path
    else
      render :edit
    end
  end

  # ❌ Missing show and destroy methods even though declared!
end
```

### The Error

User clicks link to view one type:
```
ERROR: Unknown action 'show' could not be found for EmendationTypesController
```

### The Fix

Add two missing methods:
```ruby
def show
end

def destroy
  @emendation_type.destroy
  redirect_to emendation_types_path
end
```

---

## Key Takeaway

**Golden Rule:** If you declare an action in `before_action`, you MUST define the corresponding method, OR remove it from `before_action`.

```ruby
# These must match!
before_action :hook, only: [:action1, :action2, :action3]
#                          ↓
def action1; end  # ✓
def action2; end  # ✓
def action3; end  # ✓
```

---

## For This Codebase (MyopicVicar)

### Status Check

| Controller | Issue | Method Missing |
|------------|-------|---|
| EmendationTypesController | Has before_action for show/edit/update/destroy | show |
| EmendationRulesController | Has before_action for show/edit/update/destroy | show |

### Fix

Add to each controller:
```ruby
def show
  # Rails will render app/views/[model]/show.html.erb
end
```

That's it!

