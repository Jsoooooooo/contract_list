// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TodoList {

    struct Todo {
        string text;
        bool completed;
    }

    Todo[] public todos;

    function createTodo() external {
        todos.push(Todo({
            text:_text,
            completed:true
        }));
    }
    // using calldata, cuz calldata will not change
    function updateTodo(uint256 _index,string calldata _text) external {
        //update once, using this way is much cheaper
        todos[_index].text = _text;
        // update multiple times, this way is much cheaper
        Todo storage todo = todos[_index];
        todo.text = _text;
    }

    function todoCompleted(uint256 _index) external {
        todos[index].completed = !todos[index].completed;
    }
    function get(uint256 _index) public view returns(string memory,bool){
        // memory here is a bit more expensive than storage
        Todo memory todo = todos[_index];
        return (todo.text,todo.completed);
    }
    function deleteTodo() external {}
}
