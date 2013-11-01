module ttlite where

postulate
  Level : Set
  lzero : Level
  lsuc : Level → Level
  max : Level → Level → Level

{-# BUILTIN LEVEL Level #-}
{-# BUILTIN LEVELZERO lzero #-}
{-# BUILTIN LEVELSUC lsuc #-}
{-# BUILTIN LEVELMAX max #-}

------------------------------------------
-- Dep prod (aka Π)
------------------------------------------

-- Π = forall, λ is λ 
Π : ∀ {i j : Level} (A : Set i) (P : A → Set j) → Set (max i j)
Π A P = ∀ (x : A) → P x

------------------------------------------
-- Sigma (aka Σ)
------------------------------------------

-- usually in books Σ is implemented via records, but here I would like to try data
-- Indexes are inferred
data Sigma {i j} (A : Set i) (B : A → Set j) : Set (max i j) where
  sigma₀ : (a : A) -> (_ : B a) → Sigma A B

-- using local let in order to pass indices explicitly
sigma : ∀ {i j} (A : Set i) (B : A → Set j) (a : A) (_ : B a) → Sigma A B
sigma A B a b =
  let r : Sigma A B
      r = sigma₀ a b
  in r

elimSigma : ∀ {i j k}
              (A : Set i) 
              (B : A → Set j)
              (m : Sigma A B → Set k)
              (f : (a : A) (b : B a) → m (sigma A B a b))
              (e : Sigma A B) → m e
elimSigma A B m f (sigma₀ a b) = f a b

------------------------------------------
-- Sum (aka +)
------------------------------------------

data Sum {i j} (A : Set i) (B : Set j) : Set (max i j) where
  inl₀ : A → Sum A B
  inr₀ : B → Sum A B

inl : ∀ {i j} (A : Set i) (B : Set j) (a : A) → Sum A B
inl A B a = inl₀ a

inr : ∀ {i j} (A : Set i) (B : Set j) (b : B) → Sum A B
inr A B b = inr₀ b

elimSum : ∀ {i j k} 
            (A : Set i) 
            (B : Set j) 
            (m : Sum A B → Set k) 
            (fₗ : ∀ (a : A) → m (inl A B a))
            (fᵣ : ∀ (b : B) → m (inr A B b))
            (e : Sum A B) → m e
elimSum A B m fₗ fᵣ (inl₀ a) = fₗ a
elimSum A B m fₗ fᵣ (inr₀ b) = fᵣ b

------------------------------------------
-- Falsity (aka ⊥)
------------------------------------------

data Falsity : Set lzero where

elimFalsity : ∀ {i} 
                (m : Falsity → Set i) 
                (e : Falsity) → m e
elimFalsity m ()

------------------------------------------
-- Truth (aka ⊤)
------------------------------------------

data Truth : Set lzero where
  triv : Truth

elimTruth : ∀ {i} 
              (m : Truth → Set i) 
              (f₁ : m triv) 
              (e : Truth) → m e
elimTruth m f₁ triv = f₁

------------------------------------------
-- Nat
------------------------------------------

data Nat : Set lzero where
  zero : Nat
  succ : Nat → Nat

elimNat : ∀ {i} 
            (m : Nat → Set i) 
            (f₁ : m zero) 
            (f₂ : (n : Nat) → (_ : m n) → m (succ n))
            (e : Nat) → m e
elimNat m f₁ f₂ zero     = f₁
elimNat m f₁ f₂ (succ n) = f₂ n (elimNat m f₁ f₂ n)

------------------------------------------
-- List
------------------------------------------

data List {i} (A : Set i) : Set i where
  nil₀  : List A
  cons₀ : A → List A → List A

nil : ∀ {i} (A : Set i) → List A
nil A = nil₀

cons : ∀ {i} (A : Set i) (a : A) (as : List A) → List A
cons A a as = cons₀ a as

elimList : ∀ {i j}
             (A : Set i)
             (m : List A → Set j)
             (f₁ : m (nil A))
             (f₂ : (a : A) (as : List A) (_ : m as) → m (cons A a as))
             (e : List A) → m e
elimList A m f₁ f₂ nil₀         = f₁
elimList A m f₁ f₂ (cons₀ a as) = f₂ a as (elimList A m f₁ f₂ as)

------------------------------------------
-- Identity
------------------------------------------

data Id {i} (A : Set i) (a : A) : A → Set i where
  refl₀ : Id A a a

refl : ∀ {i} (A : Set i) (a : A) → Id A a a
refl A a = refl₀

elimId : ∀ {i k}
           (A : Set i)
           (a₁ a₂ : A)
           (m : (a₁ a₂ : A) (id : Id A a₁ a₂) → Set k)
           (f₁ : (a : A) → m a a (refl A a))
           (e : Id A a₁ a₂) → m a₁ a₂ e
elimId A a .a m f refl₀ = f a

------------------------------------------
-- Extra stuff (missed in preprint)
------------------------------------------

------------------------------------------
-- Bool
------------------------------------------

data Bool : Set lzero where
  false : Bool
  true  : Bool

elimBool : ∀ {i} 
             (m : Bool → Set i)
             (f₁ : m false)
             (f₂ : m true)
             (e : Bool) → m e
elimBool m f₁ f₂ false = f₁
elimBool m f₁ f₂ true  = f₂

------------------------------------------
-- TODO: vectors, ordinary pairs, W
------------------------------------------

------------------------------------------
-- Proof combinators
-- Note that type inference is used 
-- (types of arguments are not written expl)
------------------------------------------

symm :
    forall
    (a : Set)
    (x : a)
    (y : a)
    (_ : Id a x y) →
        Id a y x
symm =
    \
    (a : Set)
    (x : a)
    (y : a)
    (eq : Id a x y) ->
        elimId a x y
            (\ x y eq_x_y -> Id a y x)
            (\ x -> refl a x)
            eq

tran :
    forall
    (a : Set)
    (x : a)
    (y : a)
    (z : a)
    (_ : Id a x y)
    (_ : Id a y z) ->
        Id a x z
tran =
   \
   (a : Set)
   (x : a)
   (y : a)
   (z : a)
   (eq_x_y : Id a x y) ->
        elimId a x y
            (\ x y eq_x_y -> forall (z : a) (_ : Id a y z) -> Id a x z)
            (\ x y eq_x_y -> eq_x_y)
            eq_x_y
            z

cong1 :
    forall
    (a : Set)
    (b : Set)
    (f : forall (_ : a) -> b)
    (x : a)
    (y : a)
    (_ : Id a x y) ->
        Id b (f x) (f y)
cong1 =
    \
    (a : Set)
    (b : Set)
    (f : forall (_ : a) -> b)
    (x : a)
    (y : a)
    (eq : Id a x y) ->
        elimId a x y
            (\ (x : a) (y : a) (eq_x_y : Id a x y) -> Id b (f x) (f y))
            (\ (x : a) -> refl b (f x))
            eq

fcong1 :
    forall
    (a : Set)
    (b : Set)
    (x : a)
    (f : forall (_ : a) -> b)
    (g : forall (_ : a) -> b)
    (_ : Id (forall (_ : a) -> b) f g) ->
        Id b (f x) (g x)
fcong1 =
    \
    (a : Set)
    (b : Set)
    (x : a)
    (f : forall (_ : a) -> b)
    (g : forall (_ : a) -> b)
    (eq : Id (forall (_ : a) -> b) f g) ->
        elimId (a → b) f g (\ f g _ -> Id b (f x) (g x)) (\ f -> refl b (f x)) eq

fargCong :
    forall
    (a : Set)
    (b : Set)
    (x : a)
    (y : a)
    (f : forall (_ : a) -> b)
    (g : forall (_ : a) -> b)
    (_ : Id a x y)
    (_ : Id (forall (_ : a) -> b) f g) ->
        Id b (f x) (g y)

fargCong =
    \
    (a : Set)
    (b : Set)
    (x : a)
    (y : a)
    (f : a → b)
    (g : a → b)
    (eq_x_y : Id a x y)
    (eq_f_g : Id (a → b) f g)  ->
        elimId (a → b) f g (\ f g _ →  Id b (f x) (g y)) (\ f → cong1 a b f x y eq_x_y) eq_f_g

cong2 :
    forall
    (a : Set)
    (b : Set)
    (c : Set)
    (f : forall (_ : a) (_ : b) -> c)
    (x1 : a)
    (x2 : a)
    (eq_xs : Id a x1 x2)
    (y1 : b)
    (y2 : b)
    (eq_ys : Id b y1 y2) ->
        Id c (f x1 y1) (f x2 y2)
cong2 =
    \
    (a : Set)
    (b : Set)
    (c : Set)
    (f : a -> b -> c)
    (x1 : a)
    (x2 : a)
    (eq_xs : Id a x1 x2)
    (y1 : b)
    (y2 : b)
    (eq_ys : Id b y1 y2) ->
        fargCong b c y1 y2 (f x1) (f x2) eq_ys (cong1 a (b -> c) f x1 x2 eq_xs)

proof_by_sc :
    forall
    (A : Set)
    (e1 : A)
    (e2 : A)
    (res : A)
    (eq_e1_res : Id A e1 res)
    (eq_e2_res : Id A e2 res) ->
        Id A e1 e2
proof_by_sc =
    \
    (A : Set)
    (e1 : A)
    (e2 : A)
    (res : A)
    (eq_e1_res : Id A e1 res)
    (eq_e2_res : Id A e2 res) ->
        tran A e1 res e2 eq_e1_res (symm A e2 res eq_e2_res)
