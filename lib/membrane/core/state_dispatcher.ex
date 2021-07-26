defmodule Membrane.Core.StateDispatcher do
  import Membrane.Core.Bin.State
  import Membrane.Core.Element.State
  import Membrane.Core.Pipeline.State

  defmacro get(state, key) do
    quote do
      case elem(unquote(state), 0) do
        :bin -> bin(unquote(state), unquote(key))
        :element -> element(unquote(state), unquote(key))
        :pipeline -> pipeline(unquote(state), unquote(key))
      end
    end
  end

  defmacro update(state, kw) do
    quote do
      case elem(unquote(state), 0) do
        :bin -> bin(unquote(state), unquote(kw))
        :element -> element(unquote(state), unquote(kw))
        :pipeline -> pipeline(unquote(state), unquote(kw))
      end
    end
  end

  defmacro get_child(state, key) do
    quote do
      case elem(unquote(state), 0) do
        :bin -> bin(unquote(state), unquote(key))
        :element -> element(unquote(state), unquote(key))
      end
    end
  end

  defmacro update_child(state, kw) do
    quote do
      case elem(unquote(state), 0) do
        :bin -> bin(unquote(state), unquote(kw))
        :element -> element(unquote(state), unquote(kw))
      end
    end
  end

  defmacro get_parent(state, key) do
    quote do
      case elem(unquote(state), 0) do
        :bin -> bin(unquote(state), unquote(key))
        :pipeline -> pipeline(unquote(state), unquote(key))
      end
    end
  end

  defmacro update_parent(state, kw) do
    quote do
      case elem(unquote(state), 0) do
        :bin -> bin(unquote(state), unquote(kw))
        :pipeline -> pipeline(unquote(state), unquote(kw))
      end
    end
  end
end
