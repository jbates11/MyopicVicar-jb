# Emendation Types Error: Complete Guide Index

## 🚨 The Error You're Seeing

```
Unknown action 'show' could not be found for EmendationRulesController
```

When you visit: `http://localhost:3000/emendation_types/index`

---

## 📋 What Happened (Simplified)

1. You tried to access a record  
2. Rails looked for a method called `show` in the controller
3. That method doesn't exist
4. Rails crashed

**Think of it like:** Ordering a meal at a restaurant, but the kitchen doesn't know how to make that dish.

---

## 🎯 Root Cause

Your controllers declare that certain actions exist but don't actually define them:

### EmendationTypesController

```ruby
before_action :set_emendation_type, only: [:show, :edit, :update, :destroy]
# ↑ Says: "I promise to have show, edit, update, destroy methods"

def edit; end      # ✓ exists
def update; end    # ✓ exists  
def destroy; end   # ✓ exists
# ❌ But show is MISSING!
```

Same issue in `EmendationRulesController`.

---

## ✅ The Fix (Choose One)

### Option A: Add the Missing Method (Recommended) ⭐

**File:** `/app/controllers/emendation_types_controller.rb`

Add this after the `new` method:
```ruby
def show
  # The before_action automatically loads @emendation_type
end
```

**Time:** 2 minutes

### Option B: Remove from Routes

**File:** `/config/routes.rb`

Change:
```ruby
resources :emendation_types
```

To:
```ruby
resources :emendation_types, except: [:show]
```

**Time:** 1 minute

**When to use:** If users never need to view one record at a time.

---

## 📚 Documentation Files Created

I've created 4 detailed guides in `/doc/emendations/`:

### 1. **ERROR_UNKNOWN_ACTION_SHOW_EXPLANATION.md** (Start Here)
   - **What:** Beginner-friendly explanation of what went wrong
   - **Length:** Medium (15 min read)
   - **Best for:** Understanding the error thoroughly
   - **Includes:**
     - Plain English explanation
     - How Rails routing works
     - Root cause analysis
     - Why the error mentions wrong controller
     - Next steps checklist

### 2. **RAILS_ACTION_FLOW_DIAGRAMS.md** (Visual Learners)
   - **What:** Mermaid diagrams showing how Rails processes requests
   - **Length:** Short (5 min read)
   - **Best for:** Visual/diagram learners
   - **Includes:**
     - Normal flow diagram
     - Broken flow diagram
     - Method comparison diagram
     - Routes vs. actions diagram
     - Error chain diagram

### 3. **CODE_FIX_MISSING_SHOW_ACTION.md** (Implementers)
   - **What:** Exact code changes needed to fix this
   - **Length:** Medium (10 min read)
   - **Best for:** Actually implementing the fix
   - **Includes:**
     - Copy-paste ready code
     - Step-by-step instructions
     - Before/after comparison
     - Testing procedure
     - Best practices to prevent this

### 4. **QUICK_REFERENCE_RAILS_ACTIONS.md** (Cheat Sheet)
   - **What:** Quick lookup for Rails concepts
   - **Length:** Short (5 min read)
   - **Best for:** Quick reference after you understand the problem
   - **Includes:**
     - Rails action reference table
     - Checklists
     - Common mistakes
     - Decision trees
     - Real examples

---

## 🚀 Quick Start: The 5-Minute Fix

### Step 1: Open the controller (30 seconds)
```
File: /app/controllers/emendation_types_controller.rb
```

### Step 2: Find the `new` method (30 seconds)
Look for:
```ruby
def new
  @emendation_type = EmendationType.new
end
```

### Step 3: Add the `show` method (1 minute)
Right after `new`, add:
```ruby
def show
  # @emendation_type is loaded by before_action :set_emendation_type
end
```

### Step 4: Restart Rails (30 seconds)
```bash
# Stop current server (Ctrl+C)
rails s
```

### Step 5: Test (2 minutes)
Visit: `http://localhost:3000/emendation_types`
- Click on any type
- Should load without "Unknown action" error

---

## ❓ FAQ

### Q: Why does the error mention EmendationRulesController instead of EmendationTypesController?

**A:** This is confusing! It could mean:
- You're actually accessing `/emendation_rules/...` instead
- A link goes to the wrong controller
- A redirect is happening
- Check your browser address bar to be sure which URL you're accessing

**Same fix applies** to both controllers if both are missing the `show` method.

### Q: Do I need to create a view file?

**A:** Not strictly required to fix the error. But if you want to display the details properly, create:
```
/app/views/emendation_types/show.html.erb
```

See **CODE_FIX_MISSING_SHOW_ACTION.md** for example template.

### Q: What's a `before_action`?

**A:** It's a Ruby hook that runs automatically before an action method. Think of it as preprocessing.

```ruby
before_action :load_data, only: [:show, :edit]
# Means: Before running show or edit, run the load_data method first
```

### Q: Why doesn't `before_action` create the method?

**A:** Because `before_action` just tells Rails to run setup code. It doesn't create the action itself. The action method (like `show`) must exist separately.

### Q: Can I just delete the `before_action` line?

**A:** No, don't do that. The `before_action` loads the record you need. Keep it and add the missing method instead.

---

## 📊 Status of Your Codebase

| Component | Status | Issue |
|-----------|--------|-------|
| EmendationTypesController | ⚠️ Broken | Missing `show` method |
| EmendationRulesController | ⚠️ Broken | Missing `show` method |
| Routes | ✅ OK | Routes are correct |
| Models | ✅ OK | Models are fine |

---

## 🎓 Key Concepts

### Rails Actions
A Rails action is a method in a controller that handles one type of request.

```ruby
def show        # This is an action
  @item = Item.find(params[:id])
end
```

### Routes
Routes map URLs to controller actions.

```ruby
GET /items/5  →  ItemsController#show
             ↑                          ↑
          URL pattern             Action method
```

### RESTful Standard
When you use `resources :model`, Rails creates 7 standard actions:
- index, new, create, show, edit, update, destroy

### The Contract
If you declare an action in `resources` or `before_action`, you must define it.

```ruby
# This contract:
resources :emendation_types
# Says: "All 7 RESTful actions exist"

# This contract:
before_action :setup, only: [:show, :edit]
# Says: "show and edit actions exist"
```

---

## 🔍 How to Know This Worked

After applying the fix:

### Test 1: No "Unknown action" error
- Visit: `http://localhost:3000/emendation_types/1`
- Should NOT see "Unknown action"

### Test 2: Server logs clean
- Run: `rails s`  
- Should start without errors
- No warnings about missing actions

### Test 3: All operations work
- ✓ List works: `/emendation_types`
- ✓ Create works: Submit form
- ✓ Edit works: Click edit button
- ✓ View works: Click on a type
- ✓ Delete works: Delete button

---

## 📞 If You're Still Stuck

### Check these things in order:

1. **Did you add the `show` method?**
   - Open `/app/controllers/emendation_types_controller.rb`
   - Search for `def show`
   - If not found, add it

2. **Did you restart Rails?**
   - Stop the server (Ctrl+C)
   - Run `rails s` again
   - Rails caches code in development mode

3. **Are you visiting the right URL?**
   - Check browser address bar
   - Should match `/emendation_types/[number]`
   - Not `/emendation_rules/...`

4. **Run tests**
   - Open Rails console: `rails c`
   - Try manually: `EmendationType.first` (should return a type)
   - Try get: `EmendationType.find(1)`

5. **Check the logs**
   - Rails log should show the exact error
   - Look for stack trace pointing to your controller

---

## 📝 Documentation Organization

```
doc/emendations/
├── README.md (this file)
├── ERROR_UNKNOWN_ACTION_SHOW_EXPLANATION.md
│   └─ For: Understanding the problem
├── RAILS_ACTION_FLOW_DIAGRAMS.md
│   └─ For: Visual learners
├── CODE_FIX_MISSING_SHOW_ACTION.md
│   └─ For: Implementing the fix
└── QUICK_REFERENCE_RAILS_ACTIONS.md
    └─ For: Quick lookup reference
```

---

## 🎯 Recommended Reading Order

**If you have 5 minutes:**
1. This file (you're reading it!)
2. Apply the fix from "Quick Start: The 5-Minute Fix" section
3. Test

**If you have 15 minutes:**
1. This file
2. **ERROR_UNKNOWN_ACTION_SHOW_EXPLANATION.md** (understand deeply)
3. **CODE_FIX_MISSING_SHOW_ACTION.md** (apply fix with context)
4. Test

**If you have 30 minutes:**
1. This file
2. **ERROR_UNKNOWN_ACTION_SHOW_EXPLANATION.md** (understand the error)
3. **RAILS_ACTION_FLOW_DIAGRAMS.md** (see visually)
4. **CODE_FIX_MISSING_SHOW_ACTION.md** (apply fix properly)
5. **QUICK_REFERENCE_RAILS_ACTIONS.md** (internalize concepts)
6. Test thoroughly
7. Improve your code per "Best Practices" section

---

## 🏆 What You'll Learn From This

After reading these documents, you'll understand:

- ✅ What Rails actions are
- ✅ How Rails routing works
- ✅ Why this specific error happens
- ✅ How to fix it (multiple ways)
- ✅ How to prevent it in future
- ✅ How to test your fix
- ✅ Rails RESTful conventions
- ✅ How `before_action` works
- ✅ How to read Rails error messages

---

## 💡 Pro Tips

1. **Use Rails console to debug:**
   ```bash
   rails c
   EmendationType.count    # How many exist?
   EmendationType.first    # Get one to test with
   ```

2. **Check routes:**
   ```bash
   rails routes | grep emendation
   # Shows what routes actually exist
   ```

3. **Read Rails logs:**
   - Look in: `log/development.log`
   - Shows detailed error information

4. **Use `raise` to debug:**
   ```ruby
   def show
     raise "DEBUG: params = #{params.inspect}"
     # This will stop execution and show you params
   end
   ```

---

## Summary

| What | Answer |
|------|--------|
| **The Error** | Missing `show` action method |
| **The Cause** | Declared but not defined |
| **The Fix** | Add: `def show; end` |
| **Time to Fix** | 2 minutes |
| **Time to Understand** | 15 minutes |
| **Difficulty** | Easy |

**Next step:** Apply the fix from the "Quick Start" section above, then read **ERROR_UNKNOWN_ACTION_SHOW_EXPLANATION.md** for deeper understanding.

