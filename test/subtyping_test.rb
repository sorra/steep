require_relative "test_helper"

class SubtypingTest < Minitest::Test
  include TestHelper
  include Steep

  BUILTIN = <<-EOB
class BasicObject
end

class Object <: BasicObject
end

class Class<'instance>
  def new: (*any, **any) -> 'instance
end

class Module
end

class String
  def to_str: -> String
end

class Integer
  def to_int: -> Integer
end
  EOB

  def new_checker(signature)
    env = AST::Signature::Env.new

    parse_signature(BUILTIN).each do |sig|
      env.add sig
    end

    parse_signature(signature).each do |sig|
      env.add sig
    end

    builder = Interface::Builder.new(signatures: env)
    Subtyping::Check.new(builder: builder)
  end

  def test_interface
    checker = new_checker(<<-EOS)
class A
  def foo: -> Integer
end

class B
  def foo: -> any
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :A),
        super_type: AST::Types::Name.new_instance(name: :B)
      )
    )

    assert_instance_of Subtyping::Result::Success, result
  end

  def test_interface2
    checker = new_checker(<<-EOS)
class A
  def foo: -> Integer
  def bar: -> any
end

class B
  def foo: -> any
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :B),
        super_type: AST::Types::Name.new_instance(name: :A)
      )
    )

    assert_instance_of Subtyping::Result::Failure, result
    assert_instance_of Subtyping::Result::Failure::MethodMissingError, result.error
    assert_equal :bar, result.error.name
    assert_equal [
                   [AST::Types::Name.new_instance(name: :B),
                    AST::Types::Name.new_instance(name: :A)]
                 ], result.trace.array
  end

  def test_interface3
    checker = new_checker(<<-EOS)
class A
  def foo: -> Integer
end

class B
  def foo: -> String
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :A),
        super_type: AST::Types::Name.new_instance(name: :B)
      )
    )

    assert_instance_of Subtyping::Result::Failure, result
    assert_instance_of Subtyping::Result::Failure::MethodMissingError, result.error
    assert_equal :to_str, result.error.name
  end

  def test_interface4
    checker = new_checker(<<-EOS)
class A
  def foo: () -> Integer
end

class B
  def foo: (?Integer, ?foo: Symbol) -> any
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :B),
        super_type: AST::Types::Name.new_instance(name: :A)
      )
    )

    assert_instance_of Subtyping::Result::Success, result
  end

  def test_interface5
    checker = new_checker(<<-EOS)
class A
  def foo: <'a> () -> 'a
end

class B
  def foo: () -> Integer
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :B),
        super_type: AST::Types::Name.new_instance(name: :A)
      )
    )
    assert_instance_of Subtyping::Result::Success, result

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :A),
        super_type: AST::Types::Name.new_instance(name: :B),
        )
    )
    assert_instance_of Subtyping::Result::Failure, result
    assert_instance_of Subtyping::Result::Failure::UnknownPairError, result.error
  end

  def test_interface6
    checker = new_checker(<<-EOS)
class A
  def foo: <'a, 'b> ('a) -> 'b
end

class B
  def foo: <'x> ('x) -> Integer
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :B),
        super_type: AST::Types::Name.new_instance(name: :A)
      )
    )
    assert_instance_of Subtyping::Result::Success, result

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :A),
        super_type: AST::Types::Name.new_instance(name: :B),
        )
    )
    assert_instance_of Subtyping::Result::Failure, result
    assert_instance_of Subtyping::Result::Failure::UnknownPairError, result.error
  end

  def test_interface7
    checker = new_checker(<<-EOS)
class A
  def foo: (Integer) -> Integer
         | (any) -> any
end

class B
  def foo: (String) -> String
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :A),
        super_type: AST::Types::Name.new_instance(name: :B)
      )
    )
    assert_instance_of Subtyping::Result::Success, result

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :B),
        super_type: AST::Types::Name.new_instance(name: :A),
        )
    )
    assert_instance_of Subtyping::Result::Failure, result
    assert_instance_of Subtyping::Result::Failure::MethodMissingError, result.error
  end

  def test_interface8
    checker = new_checker(<<-EOS)
class A
  def foo: () { -> Object } -> String
end

class B
  def foo: () { -> String } -> Object
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :A),
        super_type: AST::Types::Name.new_instance(name: :B)
      )
    )
    assert_instance_of Subtyping::Result::Success, result

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :B),
        super_type: AST::Types::Name.new_instance(name: :A),
        )
    )
    assert_instance_of Subtyping::Result::Failure, result
    assert_instance_of Subtyping::Result::Failure::MethodMissingError, result.error
  end

  def test_interface9
    checker = new_checker(<<-EOS)
class A
  def foo: () { (String) -> any } -> String
end

class B
  def foo: () { (Object) -> any } -> Object
end
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :A),
        super_type: AST::Types::Name.new_instance(name: :B)
      )
    )
    assert_instance_of Subtyping::Result::Success, result

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :B),
        super_type: AST::Types::Name.new_instance(name: :A),
        )
    )
    assert_instance_of Subtyping::Result::Failure, result
    assert_instance_of Subtyping::Result::Failure::MethodMissingError, result.error
  end

  def test_union
    checker = new_checker(<<-EOS)
    EOS

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Union.new(types: [AST::Types::Name.new_instance(name: :Object),
                                                AST::Types::Name.new_instance(name: :String)]),
        super_type: AST::Types::Name.new_instance(name: :String)
      )
    )
    assert_instance_of Subtyping::Result::Success, result

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Union.new(types: [AST::Types::Name.new_instance(name: :Object),
                                                AST::Types::Name.new_instance(name: :Integer)]),
        super_type: AST::Types::Name.new_instance(name: :String)
      )
    )
    assert_instance_of Subtyping::Result::Failure, result
    assert_equal 2, result.trace.size

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :Integer),
        super_type: AST::Types::Union.new(types: [AST::Types::Name.new_instance(name: :Object),
                                                  AST::Types::Name.new_instance(name: :BasicObject)]),
      )
    )
    assert_instance_of Subtyping::Result::Success, result

    result = checker.check(
      Subtyping::Constraint.new(
        sub_type: AST::Types::Name.new_instance(name: :Integer),
        super_type: AST::Types::Union.new(types: [AST::Types::Name.new_instance(name: :Object),
                                                  AST::Types::Name.new_instance(name: :String)]),
        )
    )
    assert_instance_of Subtyping::Result::Failure, result
  end
end
